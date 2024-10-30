# frozen_string_literal: true

# ZeroSilentFailures namespace
module ZeroSilentFailures
  # global monitoring functions for ZSF - statsd and logging
  class Monitor
    # Proxy class to allow a custom `caller_location` to be used
    class CallLocation
      attr_accessor :base_label, :path, :lineno

      # create proxy caller_location
      # @see Thread::Backtrace::Location
      # @see ZeroSilentFailures::Monitor#parse_caller
      def initialize(function = nil, file = nil, line = nil)
        @base_label = function
        @path = file
        @lineno = line
      end
    end

    # create ZSF monitor instance
    def initialize(service)
      @service = service
    end

    def log_silent_failure(additional_context, user_account_uuid = nil, call_location: nil)
      function, file, line = parse_caller(call_location)

      metric = 'silent_failure'
      message = 'Silent failure!'
      payload =  {
         statsd: metric,
         service:,
         function:,
         file:,
         line:,
         user_account_uuid:,
         additional_context:
       }

      StatsD.increment(metric, tags: ["service:#{service}", "function:#{function}"])
      Rails.logger.error(message, payload)
    end

    def log_silent_failure_avoided(additional_context, user_account_uuid = nil, call_location: nil,
                                   email_confirmed: false)
      function, file, line = parse_caller(call_location)

      metric = 'silent_failure_avoided'
      message = 'Silent failure avoided'

      unless email_confirmed
        metric = "#{metric}_no_confirmation"
        message = "#{message} (no confirmation)"
      end

      payload =  {
         statsd: metric,
         service:,
         function:,
         file:,
         line:,
         user_account_uuid:,
         additional_context:
       }

      StatsD.increment(metric, tags: ["service:#{service}", "function:#{function}"])
      Rails.logger.error(message, payload)
    end

    private

    attr_reader :service

    # parse information from the `caller`
    #
    # @see https://alextaylor.ca/read/caller-tricks/
    # @see https://stackoverflow.com/a/37565500/1812854
    # @see https://ruby-doc.org/core-2.2.3/Thread/Backtrace/Location.html
    #
    # @param call_location [CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    def parse_caller(call_location)
      call_location ||= caller_locations.second # default to location calling 'log_silent_failure...'
      [call_location.base_label, call_location.path, call_location.lineno]
    end
  end
end
