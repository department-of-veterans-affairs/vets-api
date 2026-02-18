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
    CLAIM_STATS_KEY = 'api.dependents_benefits'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.dependents_benefits_intake_job'
    # statsd key for generic module events
    MODULE_STATS_KEY = 'module.dependents_benefits'
    # statsd key for pension-related submissions
    PENSION_SUBMISSION_STATS_KEY = 'dependents_benefits.pension_submission'

    # Allowed context keys for logging
    ALLOWLIST = %w[
      tags
      submission_id
      parent_claim_id
      form_type
      from_state
      to_state
    ].freeze

    # Additional safe keys specific to dependents_benefits
    SAFE_KEYS = %w[
      parent_claim_id
    ].freeze

    def initialize
      super(service_name, allowlist: ALLOWLIST, safe_keys: SAFE_KEYS)
    end

    ##
    # Tracks a generic error event
    # Provides a general-purpose error tracking method that can be used
    # across different components with appropriate tagging
    #
    # @param message [String] Error message to log
    # @param action [String] Action being performed when error occurred
    # @param component [String, nil] Optional component name for tagging
    # @param context [Hash] Additional context data
    # @return [void]
    def track_error_event(message, action:, component: nil, **context)
      tags = { action: }
      tags[:component] = component if component
      context = append_tags(context, **tags)
      submit_event(:error, message, module_stats_key, **context)
    end

    ##
    # Tracks a generic info event
    # Provides a general-purpose info tracking method that can be used
    # across different components with appropriate tagging
    #
    # @param message [String] Info message to log
    # @param action [String] Action being performed
    # @param component [String, nil] Optional component name for tagging
    # @param context [Hash] Additional context data
    # @return [void]
    def track_info_event(message, action:, component: nil, **context)
      tags = { action: }
      tags[:component] = component if component
      context = append_tags(context, **tags)
      stats_key = context[:module_stats_key] || module_stats_key
      context.delete(:module_stats_key)
      submit_event(:info, message, stats_key, **context)
    end

    ##
    # Tracks a generic warning event
    # Provides a general-purpose warning tracking method that can be used
    # across different components with appropriate tagging
    #
    # @param message [String] Warning message to log
    # @param action [String] Action being performed
    # @param component [String, nil] Optional component name for tagging
    # @param context [Hash] Additional context data
    # @return [void]
    def track_warning_event(message, action:, component: nil, **context)
      tags = { action: }
      tags[:component] = component if component
      context = append_tags(context, **tags)
      submit_event(:warn, message, module_stats_key, **context)
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'dependents-benefits-application'
    end

    ##
    # Append tags to the context being logged
    #
    # @param context [Hash] the context being passed to the logger
    # @param tags [Mixed] the list of tags to be appended - key:value
    def append_tags(context, **tags)
      context[:tags] ||= []
      tags.each { |k, v| context[:tags] += ["#{k}:#{v}"] }
      context[:tags].uniq!
      context
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
    # Stats key for generic module events
    # @return [String]
    def module_stats_key
      MODULE_STATS_KEY
    end

    ##
    # Class name for log messages
    # @return [String]
    def name
      self.class.name
    end

    ##
    # Form ID for the dependents_benefits application
    # @return [String]
    def form_id
      DependentsBenefits::FORM_ID
    end
  end
end
