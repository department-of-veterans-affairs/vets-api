# frozen_string_literal: true

module VANotify
  module NotificationEmail

    STATSD = 'api.va_notify.notification_email'

    CONFIRMATION = :confirmation
    ERROR = :error
    RECEIVED = :received

    # error indicating failure to send email
    class FailureToSend < StandardError; end

    def monitor_send_failure(error_message, tags:, context: nil)
      metric = "#{VANotify::NotificationEmail::STATSD}.failure"
      payload = {
        statsd: metric,
        error_message:,
        context:
      }

      StatsD.increment(metric, tags:)
      Rails.logger.error('VANotify::NotificationEmail #send failure!', **payload)
    end
  end
end
