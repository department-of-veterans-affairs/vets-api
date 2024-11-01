# frozen_string_literal: true

require 'logging/monitor'

# ZeroSilentFailures namespace
module ZeroSilentFailures
  # global monitoring functions for ZSF - statsd and logging
  class Monitor < Logging::Monitor

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
