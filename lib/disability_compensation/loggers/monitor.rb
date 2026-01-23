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

      TOXIC_EXPOSURE_ALLOWLIST = %w[
        all
        completely_removed
        conditions
        conditions_state
        gulfWar1990
        gulfWar1990Details
        gulfWar2001
        gulfWar2001Details
        herbicide
        herbicideDetails
        orphaned_data_removed
        otherExposures
        otherExposuresDetails
        otherHerbicideLocations
        purge_reasons
        removed_keys
        specifyOtherExposures
        submission_id
        tags
      ].freeze

      def initialize
        super(SERVICE_NAME, allowlist: TOXIC_EXPOSURE_ALLOWLIST)
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

        # Skip if no toxic exposure data existed in save-in-progress
        return if in_progress_toxic_exposure.nil?

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

      # Logs when banking info is successfully prefilled from Lighthouse Direct Deposit API
      #
      # Veterans can have their banking info prefilled from the Lighthouse Direct Deposit API
      # during the Form 526 submission flow. We track this to monitor prefill success rates
      # and detect potential issues with the Lighthouse API integration.
      #
      # @param user_account_uuid [uuid] uuid of the user with prefilled banking info
      def track_banking_info_prefilled(user_account_uuid)
        submit_event(
          :info,
          'Banking info successfully prefilled from Lighthouse Direct Deposit API',
          "#{self.class::SUBMISSION_STATS_KEY}.banking_info_prefilled",
          user_account_uuid:,
          form_id: self.class::FORM_ID
        )
      end

      # Logs when banking info lookup returns no data on file
      #
      # When we attempt to prefill banking info from Lighthouse but the veteran has no
      # banking info on file. This helps us understand prefill failure rates and whether
      # veterans need to manually enter their banking information.
      #
      # @param user_account_uuid [uuid] uuid of the user without banking info on file
      def track_no_banking_info_on_file(user_account_uuid)
        submit_event(
          :info,
          'No banking info on file for veteran during prefill attempt',
          "#{self.class::SUBMISSION_STATS_KEY}.no_banking_info_on_file",
          user_account_uuid:,
          form_id: self.class::FORM_ID
        )
      end

      # Logs when there is an error calling the Lighthouse Direct Deposit API
      #
      # Tracks failures when attempting to retrieve banking info from Lighthouse
      # during Form 526 submission prefill. This helps identify API reliability issues
      # and their impact on the veteran experience.
      #
      # @param user_account_uuid [uuid] uuid of the user experiencing the error
      # @param error [Exception, String] exception (preferred) or error class/message
      def track_banking_info_api_error(user_account_uuid, error)
        error_class = if error.respond_to?(:class)
                        error.class.name
                      else
                        error.to_s
                      end

        submit_event(
          :error,
          'Error retrieving banking info from Lighthouse Direct Deposit API',
          "#{self.class::SUBMISSION_STATS_KEY}.banking_info_api_error",
          user_account_uuid:,
          form_id: self.class::FORM_ID,
          error: error_class
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
      # Submits a logging event to DataDog with metadata about which toxic
      # exposure keys were removed and why. Includes enough detail to verify
      # purges were appropriate without logging PII/PHI.
      #
      # @param submission [Form526Submission] The Form526Submission record
      # @param change_metadata [Hash] Hash containing removed_keys, purge_reasons, and conditions_state
      # @return [void]
      def log_toxic_exposure_changes(submission:, change_metadata:)
        log_data = {
          submission_id: submission.id,
          completely_removed: change_metadata[:completely_removed],
          removed_keys: change_metadata[:removed_keys],
          purge_reasons: change_metadata[:purge_reasons],
          conditions_state: change_metadata[:conditions_state],
          orphaned_data_removed: change_metadata[:orphaned_data_removed]
        }

        submit_event(
          :info,
          'Form526Submission toxic exposure data purged',
          "#{self.class::CLAIM_STATS_KEY}.toxic_exposure_changes",
          **log_data
        )
      end

      # Calculate removed keys from toxic exposure changes
      #
      # Analyzes differences between save-in-progress and submitted toxic exposure data
      # to identify which keys were removed and why. Distinguishes between orphaned data
      # (removed to prevent 422 errors) and user opt-outs (explicit user action).
      #
      # @param in_progress_toxic_exposure [Hash] InProgressForm data (snake_case)
      # @param submitted_toxic_exposure [Hash, nil] SavedClaim data (camelCase)
      # @return [Hash] Metadata: completely_removed, removed_keys, purge_reasons,
      #   conditions_state, orphaned_data_removed
      def calculate_toxic_exposure_changes(in_progress_toxic_exposure, submitted_toxic_exposure)
        in_progress_camelized = OliveBranch::Transformations.transform(
          in_progress_toxic_exposure, OliveBranch::Transformations.method(:camelize)
        )

        # Filter out view: prefixed keys - these are UI metadata always stripped by the
        # submit transformer, not actual purge data. Including them causes false positives.
        in_progress_keys = in_progress_camelized.keys.reject { |k| k.start_with?('view:') }
        submitted_keys = (submitted_toxic_exposure&.keys || []).reject { |k| k.start_with?('view:') }

        # Filter removed keys to only include those with actual data
        # Empty hashes {} are form scaffolding, not user data - don't count as "removed"
        potentially_removed = in_progress_keys - submitted_keys
        removed_keys = potentially_removed.select do |key|
          value = in_progress_camelized[key]
          value_has_meaningful_data?(value)
        end.sort

        purge_analysis = analyze_purge_reasons(removed_keys, in_progress_camelized, submitted_toxic_exposure)
        conditions_state = determine_conditions_state(submitted_toxic_exposure)

        {
          completely_removed: submitted_toxic_exposure.nil?,
          removed_keys:,
          purge_reasons: purge_analysis[:purge_reasons],
          conditions_state:,
          orphaned_data_removed: purge_analysis[:orphaned_data_removed]
        }
      end

      # Analyze purge reasons and detect orphaned data
      #
      # Maps each removed key to specific reason, distinguishing between:
      # - Orphaned data (no parent, causes 422 errors)
      # - User opt-outs (explicit false values, 'none' selected)
      #
      # @param removed_keys [Array<String>] Keys that were removed
      # @param _in_progress_data [Hash] InProgressForm data (camelCase) - reserved for future use
      # @param submitted_toxic_exposure [Hash, nil] The submitted toxic exposure data
      # @return [Hash] { purge_reasons: Hash, orphaned_data_removed: Boolean }
      def analyze_purge_reasons(removed_keys, _in_progress_data, submitted_toxic_exposure)
        if submitted_toxic_exposure.nil?
          return { purge_reasons: { all: 'user_opted_out_of_conditions' },
                   orphaned_data_removed: false }
        end

        has_none_selected = submitted_toxic_exposure.dig('conditions', 'none') == true
        orphaned_data_detected = false

        purge_reasons = removed_keys.each_with_object({}) do |key, reasons|
          reason, is_orphan = categorize_removed_key(key, has_none_selected, submitted_toxic_exposure)
          reasons[key] = reason
          orphaned_data_detected ||= is_orphan
        end

        { purge_reasons:, orphaned_data_removed: orphaned_data_detected }
      end

      # Categorize a single removed key and determine if it's orphaned
      #
      # @param key [String] The removed key to categorize
      # @param has_none_selected [Boolean] Whether user selected 'none' for conditions
      # @param submitted_toxic_exposure [Hash] The submitted toxic exposure data
      # @return [Array<String, Boolean>] [reason, is_orphan]
      def categorize_removed_key(key, has_none_selected, submitted_toxic_exposure)
        return ['user_selected_none_for_conditions', false] if has_none_selected
        return categorize_details_key(key, submitted_toxic_exposure) if key.end_with?('Details')
        return categorize_other_field_key(key, submitted_toxic_exposure) if other_field_key?(key)

        ['user_deselected_section', false]
      end

      # Check if key is an "other" field key
      def other_field_key?(key)
        %w[otherHerbicideLocations specifyOtherExposures].include?(key)
      end

      # Categorize a Details key (e.g., gulfWar1990Details)
      def categorize_details_key(key, submitted_toxic_exposure)
        parent_key = key.sub('Details', '')
        parent_value = submitted_toxic_exposure[parent_key]
        parent_valid = parent_value.is_a?(Hash)

        if parent_valid
          ['user_deselected_all_locations', false]
        else
          ['orphaned_details_no_parent', true]
        end
      end

      # Categorize an "other" field key (otherHerbicideLocations, specifyOtherExposures)
      def categorize_other_field_key(key, submitted_toxic_exposure)
        parent_key = key == 'otherHerbicideLocations' ? 'herbicide' : 'otherExposures'
        parent_value = submitted_toxic_exposure[parent_key]
        parent_valid = parent_value.is_a?(Hash)

        if parent_valid
          ['user_opted_out_of_other_field', false]
        else
          ['orphaned_other_field_no_parent', true]
        end
      end

      # Determine the final state of toxic exposure conditions
      #
      # @param submitted_toxic_exposure [Hash, nil] The submitted toxic exposure data
      # @return [String] One of: 'none', 'has_selections', 'empty', 'removed'
      def determine_conditions_state(submitted_toxic_exposure)
        return 'removed' if submitted_toxic_exposure.nil?

        conditions = submitted_toxic_exposure['conditions']
        return 'empty' if conditions.blank?
        return 'none' if conditions['none'] == true

        has_selections = conditions.any? { |k, v| k != 'none' && v == true }
        has_selections ? 'has_selections' : 'empty'
      end

      # Check if a value contains meaningful data (not just empty scaffolding)
      #
      # Recursively checks if a value contains actual user-entered data.
      # Empty hashes, hashes with only empty nested values, nil, and empty strings
      # are not considered meaningful data.
      #
      # @param value [Object] The value to check
      # @return [Boolean] True if the value contains meaningful data
      def value_has_meaningful_data?(value)
        case value
        when nil
          false
        when String
          value.strip.present?
        when TrueClass, FalseClass, Numeric
          true # Boolean and numeric values are meaningful (user made a selection)
        when Hash
          # Empty hash is not meaningful
          return false if value.empty?

          # Check if any nested values have meaningful data
          value.any? { |_k, v| value_has_meaningful_data?(v) }
        when Array
          value.any? { |v| value_has_meaningful_data?(v) }
        else
          value.present?
        end
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
