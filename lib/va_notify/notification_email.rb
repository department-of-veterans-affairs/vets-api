# frozen_string_literal: true

# Library for VA Notify
module VANotify
  # module functions for sending a VaNotify notification email
  module NotificationEmail
    # statsd metric prefix
    STATSD = 'api.va_notify.notification_email'

    # notification type constants
    module Type
      # confirmation
      CONFIRMATION = :confirmation
      # error
      ERROR = :error
      # received
      RECEIVED = :received
    end

    # error indicating failure to send email
    class FailureToSend < StandardError; end

    module_function

    # monitor send failure
    #
    # @param error_message [String] the error message to be logged
    # @param tags [Array<String>] array of tags for StatsD; ["tag_name:tag_value", ...]
    # @param context [Hash] additional information to send with the log
    def monitor_send_failure(error_message, tags:, context: nil)
      metric = "#{VANotify::NotificationEmail::STATSD}.send_failure"
      payload = {
        statsd: metric,
        error_message:,
        context:
      }

      StatsD.increment(metric, tags:)
      Rails.logger.error('VANotify::NotificationEmail send failure!', **payload)
    end

    # monitor attempting a duplicate notification for the same item
    #
    # @param tags [Array<String>] array of tags for StatsD; ["tag_name:tag_value", ...]
    # @param context [Hash] additional information to send with the log
    def monitor_duplicate_attempt(tags:, context: nil)
      metric = "#{VANotify::NotificationEmail::STATSD}.duplicate_attempt"
      payload = {
        statsd: metric,
        context:
      }

      StatsD.increment(metric, tags:)
      Rails.logger.warn('VANotify::NotificationEmail duplicate attempt', **payload)
    end

    # monitor delivery successful
    #
    # @param tags [Array<String>] array of tags for StatsD; ["tag_name:tag_value", ...]
    # @param context [Hash] additional information to send with the log
    def monitor_deliver_success(tags:, context: nil)
      metric = "#{VANotify::NotificationEmail::STATSD}.deliver_success"
      payload = {
        statsd: metric,
        context:
      }

      StatsD.increment(metric, tags:)
      Rails.logger.info('VANotify::NotificationEmail deliver success!', **payload)
    end
  end
end
