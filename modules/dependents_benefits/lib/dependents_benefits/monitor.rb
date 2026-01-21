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

    # statsd key for backup jobs (Lighthouse)
    BACKUP_JOB_STATS_KEY = 'app.dependents_benefits.submit_backup_job'

    # statsd key for claim processor
    PROCESSOR_STATS_KEY = 'api.dependents_benefits.claim_processor'

    # statsd key for form prefill operations
    PREFILL_STATS_KEY = 'api.dependents_benefits.prefill'

    # statsd key for pension-related submissions
    PENSION_SUBMISSION_STATS_KEY = 'app.dependents_benefits.pension_submission'

    # statsd key for unknown claim type
    UNKNOWN_CLAIM_TYPE_STATS_KEY = 'api.dependents_benefits.unknown_claim_type'

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
      super('dependents-benefits-application', allowlist: ALLOWLIST, safe_keys: SAFE_KEYS)
    end

    ##
    # Tracks an error event to Datadog and logs
    #
    # @param message [String] Error message to log
    # @param stats_key [String] Statsd key for metrics tracking
    # @param context [Hash] Additional context data (must match ALLOWLIST keys)
    # @return [void]
    def track_error_event(message, stats_key, **context)
      submit_event(:error, message, stats_key, **context)
    end

    ##
    # Tracks an info event to Datadog and logs
    #
    # @param message [String] Info message to log
    # @param stats_key [String] Statsd key for metrics tracking
    # @param context [Hash] Additional context data (must match ALLOWLIST keys)
    # @return [void]
    def track_info_event(message, stats_key, **context)
      submit_event(:info, message, stats_key, **context)
    end

    ##
    # Tracks a warning event to Datadog and logs
    #
    # @param message [String] Warning message to log
    # @param stats_key [String] Statsd key for metrics tracking
    # @param context [Hash] Additional context data (must match ALLOWLIST keys)
    # @return [void]
    def track_warning_event(message, stats_key, **context)
      submit_event(:warn, message, stats_key, **context)
    end

    ##
    # Tracks a claim processor error event
    #
    # @param message [String] Error message to log
    # @param action [String] Action being performed when error occurred
    # @param context [Hash] Additional context data
    # @return [void]
    def track_processor_error(message, action, **context)
      context = append_tags(context, action:)
      track_error_event(message, PROCESSOR_STATS_KEY, **context)
    end

    ##
    # Tracks a claim processor info event
    #
    # @param message [String] Info message to log
    # @param action [String] Action being performed
    # @param context [Hash] Additional context data
    # @return [void]
    def track_processor_info(message, action, **context)
      context = append_tags(context, action:)
      track_info_event(message, PROCESSOR_STATS_KEY, **context)
    end

    ##
    # Tracks a submission job info event
    #
    # @param message [String] Info message to log
    # @param action [String] Action being performed
    # @param context [Hash] Additional context data
    # @return [void]
    def track_submission_info(message, action, **context)
      context = append_tags(context, action:)
      track_info_event(message, SUBMISSION_STATS_KEY, **context)
    end

    ##
    # Tracks a submission job error event
    #
    # @param message [String] Error message to log
    # @param action [String] Action being performed when error occurred
    # @param context [Hash] Additional context data
    # @return [void]
    def track_submission_error(message, action, **context)
      context = append_tags(context, action:)
      track_error_event(message, SUBMISSION_STATS_KEY, **context)
    end

    ##
    # Tracks a backup job info event
    #
    # @param message [String] Info message to log
    # @param action [String] Action being performed
    # @param context [Hash] Additional context data
    # @return [void]
    def track_backup_job_info(message, action, **context)
      context = append_tags(context, action:)
      track_info_event(message, BACKUP_JOB_STATS_KEY, **context)
    end

    ##
    # Tracks a backup job warning event
    #
    # @param message [String] Warning message to log
    # @param action [String] Action being performed
    # @param context [Hash] Additional context data
    # @return [void]
    def track_backup_job_warning(message, action, **context)
      context = append_tags(context, action:)
      track_warning_event(message, BACKUP_JOB_STATS_KEY, **context)
    end

    ##
    # Tracks a backup job error event
    #
    # @param message [String] Error message to log
    # @param action [String] Action being performed when error occurred
    # @param context [Hash] Additional context data
    # @return [void]
    def track_backup_job_error(message, action, **context)
      context = append_tags(context, action:)
      track_error_event(message, BACKUP_JOB_STATS_KEY, **context)
    end

    ##
    # Tracks a form prefill warning event
    #
    # @param message [String] Warning message to log
    # @param action [String] Action being performed
    # @param context [Hash] Additional context data
    # @return [void]
    def track_prefill_warning(message, action, **context)
      context = append_tags(context, action:)
      track_warning_event(message, PREFILL_STATS_KEY, **context)
    end

    ##
    # Tracks a user data extraction error event
    #
    # @param message [String] Error message to log
    # @param action [String] Action being performed when error occurred
    # @param context [Hash] Additional context data
    # @return [void]
    def track_user_data_error(message, action, **context)
      context = append_tags(context, action:)
      track_error_event(message, CLAIM_STATS_KEY, **context)
    end

    ##
    # Tracks a user data extraction warning event
    #
    # @param message [String] Warning message to log
    # @param action [String] Action being performed
    # @param context [Hash] Additional context data
    # @return [void]
    def track_user_data_warning(message, action, **context)
      context = append_tags(context, action:)
      track_warning_event(message, CLAIM_STATS_KEY, **context)
    end

    ##
    # Tracks a pension-related submission event
    #
    # @param message [String] The message to log
    # @param context [Hash] Additional context for the event (e.g., parent_claim_id, form_type)
    # @return [void]
    def track_pension_related_submission(message, **context)
      context = append_tags(context)
      track_info_event(message, PENSION_SUBMISSION_STATS_KEY, **context)
    end

    ##
    # Tracks an unknown claim type event
    #
    # @param message [String] The message to log
    # @param context [Hash] Additional context for the event (e.g., parent_claim_id, form_type)
    # @return [void]
    def track_unknown_claim_type(message, **context)
      context = append_tags(context)
      track_warning_event(message, UNKNOWN_CLAIM_TYPE_STATS_KEY, **context)
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
