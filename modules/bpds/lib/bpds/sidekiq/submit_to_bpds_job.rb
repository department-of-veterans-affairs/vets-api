# frozen_string_literal: true

require 'bpds/service'
require 'bpds/monitor'

# This module serves as a namespace for classes and modules related to BPDS (presumably a service or subsystem).
#
# BPDS contains submodules and classes that encapsulate the logic for interacting with the BPDS service,
# including background job processing, submission tracking, and monitoring.
module BPDS
  # The Sidekiq module namespace for background job processing.
  module Sidekiq
    # SubmitToBPDSJob is a Sidekiq job responsible for submitting a SavedClaim to the BPDS service.
    #
    # This job performs the following actions:
    # - Checks if the BPDS service feature is enabled via Flipper; skips processing if disabled.
    # - Initializes the submission context for the specified SavedClaim.
    # - Prevents duplicate submissions by checking the latest submission status.
    # - Decrypts the provided payload to extract participant and file information.
    # - Submits the claim data to the BPDS service and records the submission attempt.
    # - Tracks submission success or failure using a monitoring service.
    # - Handles and logs errors, recording failed attempts and re-raising exceptions.
    # - On exhaustion of Sidekiq retries, logs the failure and records it in the submission attempts.
    #
    # @example Enqueue a submission job
    #   SubmitToBPDSJob.perform_async(saved_claim_id, encrypted_payload)
    class SubmitToBPDSJob
      include ::Sidekiq::Job
      sidekiq_options retry: 16, queue: 'low'
      sidekiq_retries_exhausted do |msg, error|
        ::Rails.logger.error("SubmitToBPDSJob exhausted all retries for saved claim ID: #{msg['args'][0]}")
        saved_claim = SavedClaim.find(msg['args'][0])
        bpds_submission = BPDS::Submission.find_by(saved_claim:)
        bpds_submission.submission_attempts.create(status: 'failure', error_message: error&.message)
      end

      # Registry mapping form IDs to their formatter classes
      FORMATTERS = {
        '21P-530EZ' => 'Burials::BPDS::Formatter'
      }.freeze

      # Submits a saved claim to the BPDS service if the feature is enabled.
      #
      # @param saved_claim_id [Integer] The ID of the saved claim to be submitted.
      # @param encrypted_payload [String] The encrypted JSON payload containing participant and file information.
      # @return [nil] Returns nil if the BPDS service feature is disabled.
      #
      # The method performs the following steps:
      # - Checks if the BPDS service feature is enabled via Flipper; returns nil if not enabled.
      # - Initializes the submission context for the given saved claim.
      # - Logs and skips submission if the claim has already been submitted.
      # - Decrypts the payload and submits the claim to the BPDS service.
      # - Records the submission attempt and tracks success or failure.
      # - Raises any exceptions encountered during submission after logging and tracking the failure.
      def perform(saved_claim_id, encrypted_payload)
        return nil unless Flipper.enabled?(:bpds_service_enabled)

        init(saved_claim_id)

        if @bpds_submission.latest_status == 'submitted'
          Rails.logger.info("Saved Claim #:#{saved_claim_id} has already been submitted to BPDS")
        end

        begin
          # Submit the BPDS submission to the BPDS service
          payload = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_payload))
          response = BPDS::Service.new.submit_json(format_claim_form(@saved_claim), @saved_claim.form_id,
                                                   payload['participant_id'], payload['file_number'])
          @bpds_submission.submission_attempts.create(status: 'submitted', response: response.to_json,
                                                      bpds_id: response['uuid'])
          @monitor.track_submit_success(saved_claim_id)
        rescue => e
          @bpds_submission.submission_attempts.create(status: 'failure', error_message: e.message)
          @monitor.track_submit_failure(saved_claim_id, e)
          raise
        end
      end

      private

      # Initializes the BPDS submission process for a given saved claim.
      #
      # @param saved_claim_id [Integer] The ID of the SavedClaim to process.
      # @return [void]
      # @raise [ActiveRecord::RecordNotFound] if the SavedClaim with the given ID does not exist.
      #
      # Finds the SavedClaim by ID, creates or finds a corresponding BPDS::Submission,
      # and initializes a BPDS::Monitor instance.
      def init(saved_claim_id)
        @saved_claim = SavedClaim.find(saved_claim_id)
        @bpds_submission = BPDS::Submission.find_or_create_by(
          saved_claim: @saved_claim,
          form_id: @saved_claim.form_id,
          reference_data_ciphertext: @saved_claim.form
        )
        @monitor = BPDS::Monitor.new
      end

      # Formats the claim's form data using a registered formatter if available.
      #
      # @param claim [SavedClaim] The claim to format
      # @return [Hash] The formatted payload (or original parsed_form if no formatter exists)
      def format_claim_form(claim)
        formatter_class_name = FORMATTERS[claim.form_id]

        return claim.parsed_form unless formatter_class_name

        formatter_class = formatter_class_name.constantize
        formatter_class.new(claim.parsed_form).format
      rescue NameError
        # Formatter class not found - fall back to unformatted parsed_form
        claim.parsed_form
      end
    end
  end
end
