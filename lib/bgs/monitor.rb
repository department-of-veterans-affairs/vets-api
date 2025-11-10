# frozen_string_literal: true

require 'logging/monitor'

module BGS
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::Logging::Monitor
    DEFAULT_STATS_KEY = 'bgs'

    def initialize
      super('bgs')
    end

    def info(message, action, **context)
      log_event(:info, message, action, **context)
    end

    def error(message, action, **context)
      log_event(:error, message, action, **context)
    end

    def warn(message, action, **context)
      log_event(:warn, message, action, **context)
    end

    private

    def log_event(level, message, action, **context)
      append_tags(context, action:)
      stats_key = context[:stats_key] || DEFAULT_STATS_KEY
      track_request(level, message, stats_key, **context)
    end

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

    ##
    # Service name used for logging
    # @return [String]
    def service_name
      'bgs'
    end
  end
end
