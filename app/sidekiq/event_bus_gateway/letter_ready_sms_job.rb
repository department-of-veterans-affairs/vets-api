# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/attr_package'
require_relative 'constants'
require_relative 'letter_ready_job_concern'

module EventBusGateway
  class LetterReadySmsJob
    include Sidekiq::Job
    include LetterReadyJobConcern

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_sms'

    sidekiq_options retry: Constants::SIDEKIQ_RETRY_COUNT_FIRST_SMS

    sidekiq_retry_in do |count, _exception|
      # Sidekiq default exponential backoff with jitter, plus one hour
      (count**4) + 15 + (rand(10) * (count + 1)) + 1.hour.to_i
    end

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      cache_key = msg['args']&.[](2)
      timestamp = Time.current

      ::Rails.logger.error('LetterReadySmsJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags:)
      Sidekiq::AttrPackage.delete(cache_key) if cache_key
    end

    def perform(participant_id, template_id, cache_key = nil) # rubocop:disable Metrics/MethodLength
      first_name = nil
      icn = nil

      # Retrieve PII from Redis if cache_key provided (avoids PII exposure in logs)
      if cache_key
        attributes = Sidekiq::AttrPackage.find(cache_key)
        if attributes
          first_name = attributes[:first_name]
          icn = attributes[:icn]
        end
      end

      # Fallback to fetching if cache_key not provided or failed
      first_name ||= get_first_name_from_participant_id(participant_id)
      icn ||= get_icn(participant_id)

      return unless validate_sms_prerequisites(template_id, first_name, icn)

      send_sms_notification(participant_id, template_id, first_name, icn)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)

      # Clean up PII from Redis if cache_key was used
      Sidekiq::AttrPackage.delete(cache_key) if cache_key
    rescue Sidekiq::AttrPackageError => e
      # Log AttrPackage errors as application logic errors (no retries)
      Rails.logger.error('LetterReadySmsJob AttrPackage error', { error: e.message })
      raise ArgumentError, e.message
    rescue => e
      record_notification_send_failure(e, 'Sms')
      raise
    end

    private

    def validate_sms_prerequisites(template_id, first_name, icn)
      if icn.blank?
        log_sms_skipped('ICN not available', template_id)
        return false
      end

      if first_name.blank?
        log_sms_skipped('First Name not available', template_id)
        return false
      end

      true
    end

    def log_sms_skipped(reason, template_id)
      ::Rails.logger.error(
        'LetterReadySmsJob sms skipped',
        {
          notification_type: 'sms',
          reason:,
          template_id:
        }
      )
      tags = Constants::DD_TAGS + ['notification_type:sms', "reason:#{reason.parameterize.underscore}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.skipped", tags:)
    end

    def send_sms_notification(participant_id, template_id, first_name, icn)
      response = notify_client.send_sms(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: {
          host: hostname_for_template,
          first_name: first_name&.capitalize
        }
      )

      create_notification_record(template_id, icn, response&.id)
    end

    def create_notification_record(template_id, icn, va_notify_id)
      notification = EventBusGatewayNotification.create(
        user_account: user_account(icn),
        template_id:,
        va_notify_id:
      )

      return if notification.persisted?

      ::Rails.logger.warn(
        'LetterReadySmsJob notification record failed to save',
        {
          errors: notification.errors.full_messages,
          template_id:,
          va_notify_id:
        }
      )
    end

    def hostname_for_template
      Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname
    end

    def notify_client
      @notify_client ||= VaNotify::Service.new(
        Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifySmsStatusCallback' }
      )
    end
  end
end
