# frozen_string_literal: true

require 'sidekiq'
require_relative 'constants'
require_relative 'letter_ready_job_concern'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job
    include LetterReadyJobConcern

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_email'

    sidekiq_options Constants::SIDEKIQ_RETRY_OPTIONS

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc

      ::Rails.logger.error('LetterReadyEmailJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags:)
    end

    def perform(participant_id, template_id, first_name = nil, icn = nil)
      # Use pre-fetched data if provided, otherwise fetch it
      first_name ||= get_first_name_from_participant_id(participant_id)
      icn ||= get_icn(participant_id)

      if icn.blank?
        ::Rails.logger.error(
          'LetterReadyEmailJob email skipped',
          {
            notification_type: 'email',
            reason: 'ICN not available',
            template_id:
          }
        )
        tags = Constants::DD_TAGS + ['notification_type:email', 'reason:icn_not_available']
        StatsD.increment("#{STATSD_METRIC_PREFIX}.skipped", tags:)
        return
      end

      send_email_notification(participant_id, template_id, first_name, icn)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
    rescue => e
      record_notification_send_failure(e, 'Email')
      raise
    end

    private

    def send_email_notification(participant_id, template_id, first_name, icn)
      response = notify_client.send_email(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: {
          host: hostname_for_template,
          first_name: first_name&.capitalize
        }
      )

      EventBusGatewayNotification.create(
        user_account: user_account(icn),
        template_id:,
        va_notify_id: response.id
      )
    end

    def hostname_for_template
      Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname
    end

    def notify_client
      @notify_client ||= VaNotify::Service.new(
        Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
      )
    end
  end
end
