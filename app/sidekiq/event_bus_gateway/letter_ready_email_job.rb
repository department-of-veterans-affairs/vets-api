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
      first_nm = first_name || get_bgs_person(participant_id)&.dig(:first_nm)
      icn = icn || get_mpi_profile(participant_id)&.icn

      if icn.present?
        response = notify_client.send_email(
          recipient_identifier: { id_value: participant_id, id_type: 'PID' },
          template_id:,
          personalisation: { host: Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
                             first_name: first_nm&.capitalize }
        )
        EventBusGatewayNotification.create(user_account: user_account(icn), template_id:,
                                           va_notify_id: response.id)
        StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
      end
    rescue => e
      record_notification_send_failure(e, 'Email')
      raise
    end

    private

    def notify_client
      @notify_client ||= VaNotify::Service.new(Constants::NOTIFY_SETTINGS.api_key,
                                               { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' })
    end
  end
end
