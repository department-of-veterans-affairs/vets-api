# frozen_string_literal: true

require 'logging/base_monitor'

module DisabilityCompensation
  module Loggers
    ##
    # Monitor class for tracking Disability Compensation claim submission events
    #
    # This class will provide methods for tracking various events during the Disability Compensation
    # submission process, including successes, failures, and retries.
    #

    class Monitor < ::Logging::BaseMonitor
      SERVICE_NAME = 'disability-compensation'
      FORM_ID = '21-526EZ-ALLCLAIMS'

      # Metrics prefixes for SavedClaim and Form526Submission events, respectively
      CLAIM_STATS_KEY = 'api.disability_compensation'
      SUBMISSION_STATS_KEY = 'api.disability_compensation.submission'

      def initialize
        super(SERVICE_NAME)
      end

      # Logs SavedClaim ActiveRecord save errors
      #
      # We use these logs to debug unforseen validation issues when
      # SavedClaim::DisabilityCompensation::Form526AllClaim saves to the database. Includes in_progress_form_id, since
      # we can use it to inspect Veteran's form choices in the production console, even if claim itself failed to save
      #
      # @param saved_claim_errors [Array<ActiveModel::Error>] array of error objects from SavedClaim that failed to save
      # @param in_progress_form_id [Integer] ID of the InProgressForm for this claim
      # @param user_account_uuid [uuid] uuid of the user attempting to save the claim
      def track_saved_claim_save_error(errors, in_progress_form_id, user_account_uuid)
        submit_event(
          :error,
          "#{self.class.name} Form526 SavedClaim save error",
          "#{self.class::CLAIM_STATS_KEY}.failure",
          in_progress_form_id:,
          user_account_uuid:,
          form_id: self.class::FORM_ID,
          errors: format_active_model_errors(errors)
        )
      end

      # Logs SavedClaim ActiveRecord save successes
      #
      # We use these logs to track when
      # SavedClaim::DisabilityCompensation::Form526AllClaim saves to the database.
      #
      # @param claim [SavedClaim::DisabilityCompensation::Form526AllClaim] the claim that was successfully saved
      # @param user_account_uuid [uuid] uuid of the user attempting to save the claim
      def track_saved_claim_save_success(claim, user_account_uuid)
        submit_event(
          :info,
          "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}",
          "#{self.class::CLAIM_STATS_KEY}.success",
          claim:,
          user_account_uuid:,
          form_id: self.class::FORM_ID
        )
      end

      # Logs toxic exposure data purge events during Form 526 submission
      #
      # Compares InProgressForm toxic exposure data with submitted claim data
      # to detect when toxic exposure data has been purged by the frontend.
      # Logs which specific keys were removed or modified to validate purge logic.
      #
      # @param in_progress_form [InProgressForm] User's saved form data
      # @param submitted_claim [SavedClaim::DisabilityCompensation::Form526AllClaim] The submitted claim
      # @param submission [Form526Submission] The submission record
      # @param user_uuid [String] User's UUID
      def track_toxic_exposure_purge(in_progress_form:, submitted_claim:, submission:, user_uuid:)
        sip_data = parse_form_data(in_progress_form.form_data)
        submitted_data = parse_form_data(submitted_claim.form)
        return unless sip_data && submitted_data

        sip_toxic_exposure = sip_data.dig('form526', 'toxicExposure')
        submitted_toxic_exposure = submitted_data.dig('form526', 'toxicExposure')

        # Only log if toxic exposure existed in SIP but changed or was removed
        return if sip_toxic_exposure.nil? || sip_toxic_exposure == submitted_toxic_exposure

        change_metadata = calculate_toxic_exposure_changes(sip_toxic_exposure, submitted_toxic_exposure)
        log_toxic_exposure_changes(
          in_progress_form:,
          submitted_claim:,
          submission:,
          user_uuid:,
          change_metadata:
        )
      end

      private

      # Parse form data from JSON string or Hash
      def parse_form_data(data)
        return data if data.is_a?(Hash)
        return JSON.parse(data) if data.is_a?(String)

        nil
      rescue JSON::ParserError
        nil
      end

      # Loops through array of ActiveModel::Error instances and formats a readable log
      def format_active_model_errors(errors)
        errors.map { |error| { "#{error.attribute}": error.type.to_s } }.to_s
      end

      # Calculate which keys have been modified (present in both but with different values)
      def calculate_modified_keys(sip_toxic_exposure, submitted_toxic_exposure)
        return [] if submitted_toxic_exposure.nil?
        return [] if sip_toxic_exposure.nil?

        sip_toxic_exposure.keys.select do |key|
          submitted_toxic_exposure.key?(key) && sip_toxic_exposure[key] != submitted_toxic_exposure[key]
        end
      end

      # Log the toxic exposure changes with metadata
      def log_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:,
                                     user_uuid:, change_metadata:)
        log_data = {
          user_uuid:,
          in_progress_form_id: in_progress_form.id,
          saved_claim_id: submitted_claim.id,
          form526_submission_id: submission.id,
          confirmation_number: submitted_claim.confirmation_number,
          had_toxic_exposure_in_sip: true,
          has_toxic_exposure_in_submission: change_metadata[:has_toxic_exposure_in_submission],
          completely_removed: change_metadata[:completely_removed],
          removed_keys: change_metadata[:removed_keys],
          modified_keys: change_metadata[:modified_keys]
        }

        submit_event(
          :info,
          "Form526Submission=#{submission.id} ToxicExposurePurge=detected",
          "#{self.class::CLAIM_STATS_KEY}.toxic_exposure_purge",
          log_data
        )
      end

      # Calculate removed and modified keys from toxic exposure changes
      def calculate_toxic_exposure_changes(sip_toxic_exposure, submitted_toxic_exposure)
        removed_keys = sip_toxic_exposure.keys - (submitted_toxic_exposure&.keys || [])
        modified_keys = calculate_modified_keys(sip_toxic_exposure, submitted_toxic_exposure)

        {
          has_toxic_exposure_in_submission: !submitted_toxic_exposure.nil?,
          completely_removed: submitted_toxic_exposure.nil?,
          removed_keys: removed_keys.sort,
          modified_keys: modified_keys.sort
        }
      end

      ##
      # Module application name used for logging
      # @return [String]
      def service_name
        SERVICE_NAME
      end

      ##
      # Stats key for DD
      # @return [String]
      def claim_stats_key
        CLAIM_STATS_KEY
      end

      ##
      # Stats key for Sidekiq DD logging
      # @return [String]
      def submission_stats_key
        SUBMISSION_STATS_KEY
      end

      ##
      # Class name for log messages
      # @return [String]
      def name
        self.class.name
      end

      ##
      # Form ID for the application
      # @return [String]
      def form_id
        FORM_ID
      end
    end
  end
end
