# frozen_string_literal: true

require 'logging/monitor'

module DecisionReviews
  class NotificationMonitor < Logging::Monitor
    def log_silent_failure
    end

    def log_silent_failure_avoided(additional_context, _user_account_uuid = nil, call_location: nil,
                                   email_confirmed: false)
      metric = 'silent_failure_avoided'
      message = 'Silent failure avoided'
      function = additional_context[:function]

      unless email_confirmed
        metric = "#{metric}_no_confirmation"
        message = "#{message} (no confirmation)"
      end

      payload = {
        service:,
        function:,
        additional_context:
      }

      StatsD.increment(metric, tags: ["service:#{service}", "function:#{function}"])
      Rails.logger.error(message, payload)
    end
  end
end
