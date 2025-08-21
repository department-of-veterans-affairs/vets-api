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
      FORM_ID = '21-526EZ'

      # Metrics prefixes for SavedClaim and Form526Submission events, respectively
      CLAIM_STATS_KEY = 'api.disability_compensation.claim'
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
      # @param user_uuid [uuid] uuid of the user attempting to save the claim
      def track_saved_claim_save_error(errors, in_progress_form_id, user_uuid)
        submit_event(
          :error,
          "#{self.class.name} Form526 SavedClaim save error",
          self.class::CLAIM_STATS_KEY,
          in_progress_form_id:,
          user_account_uuid: user_uuid,
          form_id: '21-526EZ-ALLCLAIMS',
          errors: format_active_model_errors(errors)
        )
      end

      private

      # Loops through array of ActiveModel::Error instances and formats a readable log
      def format_active_model_errors(errors)
        errors.map { |error| { "#{error.attribute}": error.type.to_s } }.to_s
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
