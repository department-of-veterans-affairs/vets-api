# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/attr_package'
require_relative 'constants'
require_relative 'errors'
require_relative 'letter_ready_job_concern'

module EventBusGateway
  class LetterReadyPushJob
    include Sidekiq::Job
    include LetterReadyJobConcern

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_push'

    sidekiq_options retry: Constants::SIDEKIQ_RETRY_COUNT_FIRST_PUSH

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc
      cache_key = msg['args'][2]

      ::Rails.logger.error('LetterReadyPushJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags:)
      Sidekiq::AttrPackage.delete(cache_key) if cache_key
    end

    def perform(participant_id, template_id, cache_key = nil)
      icn = nil

      # Retrieve PII from Redis if cache_key provided (avoids PII exposure in logs)
      if cache_key
        attributes = Sidekiq::AttrPackage.find(cache_key)
        icn = attributes[:icn] if attributes
      end

      # Fallback to fetching if cache_key not provided or failed
      icn ||= get_icn(participant_id)

      raise Errors::IcnNotFoundError, 'Failed to fetch ICN' if icn.blank?

      send_push_notification(icn, template_id)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
      Sidekiq::AttrPackage.delete(cache_key) if cache_key
    rescue Sidekiq::AttrPackageError => e
      # Log AttrPackage errors as application logic errors (no retries)
      Rails.logger.error('LetterReadyPushJob AttrPackage error', { error: e.message })
      raise ArgumentError, e.message
    rescue => e
      record_notification_send_failure(e, 'Push')
      raise
    end

    private

    def send_push_notification(icn, template_id)
      notify_client.send_push(
        mobile_app: 'VA_FLAGSHIP_APP',
        recipient_identifier: { id_value: icn, id_type: 'ICN' },
        template_id:,
        personalisation: {}
      )

      create_push_notification_record(template_id, icn)
    end

    def create_push_notification_record(template_id, icn)
      notification = EventBusGatewayPushNotification.create(
        user_account: user_account(icn),
        template_id:
      )

      return if notification.persisted?

      ::Rails.logger.warn(
        'LetterReadyPushJob notification record failed to save',
        {
          errors: notification.errors.full_messages,
          template_id:
        }
      )
    end

    def notify_client
      # Push notifications require a separate API key from email and sms
      @notify_client ||= VaNotify::Service.new(Constants::NOTIFY_SETTINGS.push_api_key)
    end
  end
end
