# frozen_string_literal: true

module Logging
  # generic monitoring class
  class Monitor
    # create a monitor
    def initialize(service)
      @service = service
    end

    ##
    # monitor application
    #
    # @param error_level [String]
    # @param message [String]
    # @param metric [String]
    # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    # @param context [Hash] additional parameters to pass to log
    def track_request(error_level, message, metric, call_location: nil, **additional_context)
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric, tags: additional_context[:tags])

      if %w[debug info warn error fatal unknown].include?(error_level)
        payload = {
          statsd: metric,
          service:,
          user_account_uuid: additional_context[:user_account_uuid],
          function:,
          file:,
          line:,
          additional_context: context
        }
        Rails.logger.public_send(error_level, message.to_s, payload)
      else
        Rails.logger.error("Invalid log error_level: #{error_level}")
      end
    end

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
