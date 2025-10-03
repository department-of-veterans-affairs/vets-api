# frozen_string_literal: true

require 'logging/base_monitor'

module DependentsBenefits
  ##
  # Monitor class for tracking claim submission events
  #
  # This class provides methods for tracking various events during the dependents_benefits claim
  # submission process, including successes, failures, and retries.
  #
  # @example Tracking a submission success
  #   monitor = DependentsBenefits::Monitor.new
  #   monitor.track_submission_success(claim, service, user_uuid)
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.dependents_benefits_claim'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'app.dependents_benefits.submit_benefits_intake_claim'

    PROCESSOR_STATS_KEY = 'api.dependents_benefits.claim_processor'

    PREFILL_STATS_KEY = 'api.dependents_benefits.prefill'

    def initialize
      super('dependents-benefits-application')
    end

    def track_error_event(message, stats_key, **context)
      submit_event(:error, message, stats_key, **context)
    end

    def track_info_event(message, stats_key, **context)
      submit_event(:info, message, stats_key, **context)
    end

    def track_warning_event(message, stats_key, **context)
      submit_event(:warn, message, stats_key, **context)
    end

    def track_processor_error(message, action, **context)
      context = append_tags(context, action:)
      track_error_event(message, PROCESSOR_STATS_KEY, **context)
    end

    def track_processor_info(message, action, **context)
      context = append_tags(context, action:)
      track_info_event(message, PROCESSOR_STATS_KEY, **context)
    end

    def track_submission_info(message, action, **context)
      context = append_tags(context, action:)
      track_info_event(message, SUBMISSION_STATS_KEY, **context)
    end

    def track_submission_error(message, action, **context)
      context = append_tags(context, action:)
      track_error_event(message, SUBMISSION_STATS_KEY, **context)
    end

    def track_prefill_warning(message, action, **context)
      context = append_tags(context, action:)
      track_warning_event(message, PREFILL_STATS_KEY, **context)
    end

    def track_user_data_error(message, action, options = {})
      options[:tags] = ["action:user_data.#{action}"]
      track_error_event(message, CLAIM_STATS_KEY, options)
    end

    def track_user_data_warning(message, action, options = {})
      options[:tags] = ["action:user_data.#{action}"]
      track_warning_event(message, CLAIM_STATS_KEY, options)
    end

    private

    # append tags to the context being logged
    #
    # @param context [Hash] the context being passed to the logger
    # @param tags [Mixed] the list of tags to be appended - key:value
    def append_tags(context, **tags)
      context[:tags] ||= []
      tags.each { |k, v| context[:tags] += ["#{k}:#{v}"] }
      context[:tags].uniq!
      context
    end

    # Module application name used for logging
    # @return [String]
    def service_name
      'dependents-benefits-application'
    end

    # Stats key for DD
    # @return [String]
    def claim_stats_key
      CLAIM_STATS_KEY
    end

    # Stats key for Sidekiq DD logging
    # @return [String]
    def submission_stats_key
      SUBMISSION_STATS_KEY
    end

    # Class name for log messages
    # @return [String]
    def name
      self.class.name
    end

    # Form ID for the dependents_benefits application
    # @return [String]
    def form_id
      DependentsBenefits::FORM_ID
    end
  end
end
