# frozen_string_literal: true

module Logging
  # generic monitoring class
  class Monitor
    # create a monitor
    #
    # @param service [String] the service name for this monitor; will be included with each log message
    def initialize(service)
      @service = service
    end

    # perform monitoring actions - StatsD.increment and Rails.logger
    #
    # @param error_level [String|Symbol] the log level to Rails.logger
    # @param message [String] the message to be logged
    # @param metric [String] the metric to be incremented
    # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    # @param **context [Hash] additional parameters to pass to log; if `tags` is provided it will be included in StatsD
    def track_request(error_level, message, metric, call_location: nil, **context)
      function, file, line = parse_caller(call_location)

      tags = (["service:#{service}", "function:#{function}"] + (context[:tags] || [])).uniq
      StatsD.increment(metric, tags:)

      if %w[debug info warn error fatal unknown].include?(error_level.to_s)
        payload = {
          statsd: metric,
          service:,
          function:,
          file:,
          line:,
          context:
        }
        Rails.logger.public_send(error_level, message.to_s, payload)
      else
        Rails.logger.error("Invalid log error_level: #{error_level}")
      end
    end

    alias track track_request

    private

    attr_reader :service

    # parse information from the `caller`
    # defaults to the location calling `track_request`
    #
    # @see https://alextaylor.ca/read/caller-tricks/
    # @see https://stackoverflow.com/a/37565500/1812854
    # @see https://ruby-doc.org/core-2.2.3/Thread/Backtrace/Location.html
    #
    # @param call_location [CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    def parse_caller(call_location)
      call_location ||= caller_locations.second
      [call_location.base_label, call_location.path, call_location.lineno]
    end
  end
end
