# frozen_string_literal: true

require 'logging/monitor'

module DecisionReviews
  class NotificationMonitor < Logging::Monitor
    def track(error_level, message, metric, call_location: nil, **context) # rubocop:disable Lint/UnusedMethodArgument
      function = context[:callback_metadata][:function]
      tags = (["service:#{service}", "function:#{function}"] + (context[:tags] || [])).uniq
      StatsD.increment(metric, tags:)

      if %w[debug info warn error fatal unknown].include?(error_level.to_s)
        payload = {
          statsd: metric,
          service:,
          function:,
          context:
        }
        Rails.logger.public_send(error_level, message.to_s, payload)
      else
        Rails.logger.error("Invalid log error_level: #{error_level}")
      end
    end

    def log_silent_failure(additional_context, _user_account_uuid = nil, call_location: nil) # rubocop:disable Lint/UnusedMethodArgument
      metric = 'silent_failure'
      message = 'Silent failure!'
      function = additional_context[:callback_metadata][:function]

      payload = {
        statsd: metric,
        service:,
        function:,
        additional_context:
      }

      StatsD.increment(metric, tags: ["service:#{service}", "function:#{function}"])
      Rails.logger.error(message, payload)
    end

    def log_silent_failure_avoided(additional_context, _user_account_uuid = nil, call_location: nil, # rubocop:disable Lint/UnusedMethodArgument
                                   email_confirmed: false)
      metric = 'silent_failure_avoided'
      message = 'Silent failure avoided'
      function = additional_context[:callback_metadata][:function]
      unless email_confirmed
        metric = "#{metric}_no_confirmation"
        message = "#{message} (no confirmation)"
      end

      payload = {
        statsd: metric,
        service:,
        function:,
        additional_context:
      }

      StatsD.increment(metric, tags: ["service:#{service}", "function:#{function}"])
      Rails.logger.error(message, payload)
    end
  end
end
