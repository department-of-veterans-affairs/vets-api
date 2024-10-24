# frozen_string_literal: true

module VANotify
  module NotificationEmail
    STATSD = 'api.va_notify.notification_email'

    CONFIRMATION = :confirmation
    ERROR = :error
    RECEIVED = :received

    # error indicating failure to send email
    class FailureToSend < StandardError; end

    module_function

    def monitor_send_failure(error_message, tags:, context: nil)
      metric = "#{VANotify::NotificationEmail::STATSD}.send_failure"
      payload = {
        statsd: metric,
        error_message:,
        context:
      }

      StatsD.increment(metric, tags:)
      Rails.logger.error('VANotify::NotificationEmail #send failure!', **payload)
    end

    def monitor_duplicate_attempt(tags:, context: nil)
      metric = "#{VANotify::NotificationEmail::STATSD}.duplicate_attempt"
      payload = {
        statsd: metric,
        context:
      }

      StatsD.increment(metric, tags:)
      Rails.logger.warn('VANotify::NotificationEmail #send duplicate attempt', **payload)
    end
  end
end
