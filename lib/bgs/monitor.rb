# frozen_string_literal: true

require 'logging/monitor'

module BGS
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::Logging::Monitor
    DEFAULT_STATS_KEY = 'bgs'
    ALLOWLIST = %w[
      action
      error
      error_class
      from_state
      job_id
      message
      source
      stats_key
      submission_id
      tags
      to_state
      user_uuid
    ].freeze

    def initialize(allowlist: [])
      super('bgs', allowlist: ALLOWLIST + allowlist)
    end

    # Logs an info-level event with action and context
    #
    # @param message [String] Log message
    # @param action [String] Action identifier for tagging
    # @param context [Hash] Additional context for logging
    def info(message, action, **context)
      log_event(:info, message, action, **context)
    end

    # Logs an error-level event with action and context
    #
    # @param message [String] Log message
    # @param action [String] Action identifier for tagging
    # @param context [Hash] Additional context for logging
    def error(message, action, **context)
      log_event(:error, message, action, **context)
    end

    # Logs a warning-level event with action and context
    #
    # @param message [String] Log message
    # @param action [String] Action identifier for tagging
    # @param context [Hash] Additional context for logging
    def warn(message, action, **context)
      log_event(:warn, message, action, **context)
    end

    private

    def log_event(level, message, action, **context)
      append_tags(context, action:)
      stats_key = context[:stats_key] || DEFAULT_STATS_KEY
      track_request(level, message, stats_key, action:, **context)
    end

    # Appends tags to the context being logged
    #
    # @param context [Hash] Context being passed to the logger
    # @param tags [Hash] Tags to append as key:value pairs
    # @return [Hash] Updated context with appended tags
    def append_tags(context, **tags)
      context[:tags] ||= []
      tags.each { |k, v| context[:tags] << "#{k}:#{v}" }
      context[:tags].uniq!
      context
    end
  end
end
