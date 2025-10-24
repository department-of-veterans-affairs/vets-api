# frozen_string_literal: true

require 'dependents_verification/notification_email'
require 'logging/base_monitor'

module DependentsVerification
  ##
  # Monitor class for tracking claim submission events
  #
  # This class provides methods for tracking various events during the dependents verification
  # submission process, including successes, failures, and retries.
  #
  # @example Tracking a submission success
  #   monitor = DependentsVerification::Monitor.new
  #   monitor.track_submission_success(claim, service, user_uuid)
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.dependents_verification'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'app.dependents_verification.submit_benefits_intake_claim'

    def initialize
      super('dependents-verification')
    end

    ##
    # Tracks a failure in prefill
    #
    # @param category [String] The category of the prefill that failed
    # @param error [StandardError] The error that occurred during prefill
    # @return [void]
    def track_prefill_error(category, error)
      message = "Form21-0538 #{category} prefill failed. #{error.message}"
      stats_key = "#{claim_stats_key}.prefill_error"
      context = { error: error.message }

      submit_event(:info, message, stats_key, **context)
    end

    ##
    # Tracks missing dependent information from dependents service
    #
    # @param error [StandardError] The error that occurred during prefill
    # @return [void]
    def track_missing_dependent_info
      message = 'Form21-0538 missing dependent information.'
      stats_key = "#{claim_stats_key}.missing_dependent_info"

      submit_event(:info, message, stats_key) # no additional context
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'dependents-verification'
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
      DependentsVerification::FORM_ID
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(claim_id, email_type)
      DependentsVerification::NotificationEmail.new(claim_id).deliver(email_type)
    end
  end
end
