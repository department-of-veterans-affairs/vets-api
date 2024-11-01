# frozen_string_literal: true

require 'logging/monitor'

# ZeroSilentFailures namespace
module ZeroSilentFailures
  # global monitoring functions for ZSF - statsd and logging
  # @see Logging::Monitor
  class Monitor < Logging::Monitor
    # record metrics and log for a silent failure
    # @param additional_context [Hash] information to accompany the log to aid in debugging
    # @param user_account_uuid [UUID]
    # @param call_location [CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    def log_silent_failure(additional_context, user_account_uuid = nil, call_location: nil)
      function, file, line = parse_caller(call_location || caller_locations.first)

      metric = 'silent_failure'
      message = 'Silent failure!'
      payload = {
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

    # record metrics and log for a silent failure, avoided - an email was sent
    # @param additional_context [Hash] information to accompany the log to aid in debugging
    # @param user_account_uuid [UUID]
    # @param call_location [CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    # @param email_confirmed [Boolean] whether the email was successfully delivered
    def log_silent_failure_avoided(additional_context, user_account_uuid = nil, call_location: nil,
                                   email_confirmed: false)
      function, file, line = parse_caller(call_location || caller_locations.first)

      metric = 'silent_failure_avoided'
      message = 'Silent failure avoided'

      unless email_confirmed
        metric = "#{metric}_no_confirmation"
        message = "#{message} (no confirmation)"
      end

      payload = {
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
  end
end
