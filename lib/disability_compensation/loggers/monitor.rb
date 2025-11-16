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
        super(SERVICE_NAME, allowlist: %w[completely_removed removed_keys submission_id tags])
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

      # Logs toxic exposure data changes during Form 526 submission
      #
      # Compares InProgressForm toxic exposure data with submitted claim data
      # to detect when toxic exposure data has been changed or removed by the frontend.
      # Logs which specific keys were removed to validate purge logic.
      #
      # @param in_progress_form [InProgressForm] User's saved form data
      # @param submitted_claim [SavedClaim::DisabilityCompensation::Form526AllClaim] The submitted claim
      # @param submission [Form526Submission] The submission record
      # @return [void]
      def track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
        in_progress_form_data = parse_form_data(in_progress_form.form_data)
        submitted_data = parse_form_data(submitted_claim.form)

        return unless in_progress_form_data && submitted_data

        # NOTE: Both InProgressForm.form_data and SavedClaim.form store only the inner
        # content of the form526 submission (without the 'form526' wrapper).
        # The wrapper only exists in the original HTTP request body.
        # InProgressForm uses snake_case, SavedClaim uses camelCase (transformation happens during submission)
        in_progress_toxic_exposure = in_progress_form_data['toxic_exposure']
        submitted_toxic_exposure = submitted_data['toxicExposure']

        # Only log if toxic exposure existed in save-in-progress but changed or was removed
        return if in_progress_toxic_exposure.nil? || in_progress_toxic_exposure == submitted_toxic_exposure

        change_metadata = calculate_toxic_exposure_changes(in_progress_toxic_exposure, submitted_toxic_exposure)

        # Don't log if no meaningful changes (after filtering empty hashes)
        return if change_metadata[:removed_keys].empty? && !change_metadata[:completely_removed]

        log_toxic_exposure_changes(
          submission:,
          change_metadata:
        )
      end

      # Logs Form526 submission with provided direct deposit banking info
      #
      # Veterans have the option to provide banking account info for direct deposit of their benefits,
      # which we prefill via the Lighthouse Direct Deposit API https://dev-developer.va.gov/explore/api/direct-deposit-management
      # if Lighthouse has it on file; if not they may enter it themselves.
      # We track this to monitor how frequently submissions are coming through with or without this info, in case there
      # is an unusual number of submissions without banking info which could indicate a problem
      #
      # @param user_account_uuid [uuid] uuid of the user attempting to save the claim
      def track_526_submission_with_banking_info(user_account_uuid)
        submit_event(
          :info,
          'Form 526 submitted with Veteran-supplied banking info',
          "#{self.class::SUBMISSION_STATS_KEY}.with_banking_info",
          user_account_uuid:,
          form_id: self.class::FORM_ID
        )
      end

      # Logs Form526 submission without provided direct deposit banking info
      #
      # We track this to monitor how frequently submissions are coming through with or without this info, in case there
      # is an unusual number of submissions without banking info which could indicate a problem
      #
      # @param user_account_uuid [uuid] uuid of the user attempting to save the claim
      def track_526_submission_without_banking_info(user_account_uuid)
        submit_event(
          :info,
          'Form 526 submitted without Veteran-supplied banking info',
          "#{self.class::SUBMISSION_STATS_KEY}.without_banking_info",
          user_account_uuid:,
          form_id: self.class::FORM_ID
        )
      end

      private

      # Parse form data from JSON string or Hash
      #
      # Handles both Hash and JSON string formats for form data
      # and returns nil for invalid JSON or unsupported types.
      #
      # @param data [Hash, String] Form data to parse
      # @return [Hash, nil] Parsed form data hash or nil if parsing fails
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

      # Log the toxic exposure changes with metadata
      #
      # Submits a logging event to DataDog with minimal metadata about
      # which toxic exposure keys were removed during submission.
      # Uses minimal data to reduce fingerprinting risk.
      #
      # @param submission [Form526Submission] The Form526Submission record
      # @param change_metadata [Hash] Hash containing removed_keys and removal flags
      # @return [void]
      def log_toxic_exposure_changes(submission:, change_metadata:)
        log_data = {
          submission_id: submission.id,
          completely_removed: change_metadata[:completely_removed],
          removed_keys: change_metadata[:removed_keys]
        }

        submit_event(
          :info,
          'Form526Submission toxic exposure orphaned dates purged',
          "#{self.class::CLAIM_STATS_KEY}.toxic_exposure_changes",
          **log_data
        )
      end

      # Calculate removed keys from toxic exposure changes
      #
      # Analyzes differences between save-in-progress and submitted toxic exposure data
      # to identify which keys were removed. Filters out empty hash values to reduce noise.
      #
      # @param in_progress_toxic_exposure [Hash] InProgressForm data (snake_case)
      # @param submitted_toxic_exposure [Hash, nil] SavedClaim data (camelCase)
      # @return [Hash] Metadata with completely_removed and removed_keys
      def calculate_toxic_exposure_changes(in_progress_toxic_exposure, submitted_toxic_exposure)
        in_progress_camelized = OliveBranch::Transformations.transform(
          in_progress_toxic_exposure,
          OliveBranch::Transformations.method(:camelize)
        )

        in_progress_camel_keys = in_progress_camelized.keys
        submitted_camel_keys = submitted_toxic_exposure&.keys || []

        all_removed_keys = in_progress_camel_keys - submitted_camel_keys

        # Filter out empty hashes to reduce noise
        removed_keys = all_removed_keys.reject do |camel_key|
          in_progress_camelized[camel_key].is_a?(Hash) && in_progress_camelized[camel_key].empty?
        end

        completely_removed = submitted_toxic_exposure.nil?

        {
          completely_removed:,
          removed_keys: removed_keys.sort
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
