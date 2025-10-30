# frozen_string_literal: true

require 'sidekiq'
require_relative 'constants'

module EventBusGateway
  class LetterReadyRetryEmailJob
    include Sidekiq::Job

    class EventBusGatewayNotificationNotFoundError < StandardError; end

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_retry_email'

    sidekiq_options retry: Constants::SIDEKIQ_RETRY_COUNT_RETRY_EMAIL

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc

      ::Rails.logger.error('LetterReadyRetryEmailJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags: Constants::DD_TAGS)
    end

    def perform(participant_id, template_id, personalisation, notification_id)
      original_notification = EventBusGatewayNotification.find_by(id: notification_id)
      raise EventBusGatewayNotificationNotFoundError if original_notification.nil?

      response = notify_client.send_email(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation:
      )

      increment_attempts_counter(original_notification, response.id)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
    rescue => e
      record_email_send_failure(e)
      raise
    end

    private

    def notify_client
      @notify_client ||= VaNotify::Service.new(Constants::NOTIFY_SETTINGS.api_key,
                                               { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' })
    end

    def increment_attempts_counter(original_notification, new_va_notify_id)
      original_notification.update!(
        attempts: original_notification.attempts + 1,
        va_notify_id: new_va_notify_id
      )
    end

    def record_email_send_failure(error)
      error_message = 'LetterReadyRetryEmailJob email error'
      ::Rails.logger.error(error_message, { message: error.message })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.failure", tags:)
    end
  end
end
