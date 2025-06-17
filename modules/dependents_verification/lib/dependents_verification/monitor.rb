# frozen_string_literal: true

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

    attr_reader :tags

    def initialize
      super('dependents-verification')

      @tags = ["form_id:#{form_id}"]
    end

    ##
    # Tracks a failure in prefill
    #
    # @param category [String] The category of the prefill that failed
    # @param error [StandardError] The error that occurred during prefill
    # @return [void]
    def track_prefill_error(category, error)
      submit_event('info', "Form21-0538 #{category} prefill failed. #{error.message}",
                   "#{claim_stats_key}.prefill_error", { form_id:, tags: })
    end

    ##
    # Tracks missing dependent information from dependents service
    #
    # @param error [StandardError] The error that occurred during prefill
    # @return [void]
    def track_missing_dependent_info
      submit_event('info', 'Form21-0538 missing dependent information.',
                   "#{claim_stats_key}.missing_dependent_info", { form_id:, tags: })
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
  end
end
