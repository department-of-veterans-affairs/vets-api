# frozen_string_literal: true

require 'bpds/service'
require 'bpds/monitor'

module BPDS
  module Sidekiq
    class SubmitToBPDSJob
      include ::Sidekiq::Job
      sidekiq_options retry: 16, queue: 'low'
      sidekiq_retries_exhausted do |msg, error|
        ::Rails.logger.error("SubmitToBPDSJob exhausted all retries for saved claim ID: #{msg['args'][0]}")
        saved_claim = SavedClaim.find(msg['args'][0])
        bpds_submission = BPDS::Submission.find_by(saved_claim:)
        bpds_submission.submission_attempts.create(status: 'failure', error_message: error&.message)
      end

      def perform(saved_claim_id)
        return nil unless Flipper.enabled?(:bpds_service_enabled)

        init(saved_claim_id)

        if @bpds_submission.latest_status == 'submitted'
          Rails.logger.info("Saved Claim #:#{saved_claim_id} has already been submitted to BPDS")
        end

        begin
          # Submit the BPDS submission to the BPDS service
          response = BPDS::Service.new.submit_json(@saved_claim)
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

      def init(saved_claim_id)
        @saved_claim = SavedClaim.find(saved_claim_id)
        @bpds_submission = BPDS::Submission.find_or_create_by(
          saved_claim: @saved_claim,
          form_id: @saved_claim.form_id,
          reference_data_ciphertext: @saved_claim.form
        )
        @monitor = BPDS::Monitor.new
      end
    end
  end
end
