# frozen_string_literal: true

require 'sidekiq'
require_relative 'constants'
require_relative 'letter_ready_job_concern'

module EventBusGateway
  class LetterReadyPushJob
    include Sidekiq::Job
    include LetterReadyJobConcern

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_push'

    sidekiq_options Constants::SIDEKIQ_RETRY_OPTIONS

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc

      ::Rails.logger.error('LetterReadyPushJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags:)
    end

    def perform(participant_id, template_id, icn = nil)
      icn = icn || get_mpi_profile(participant_id)&.icn

      if icn.present?
        notify_client.send_push(
          mobile_app: 'VA_FLAGSHIP_APP',
          recipient_identifier: { id_value: icn, id_type: 'ICN' },
          template_id:,
          personalisation: {}
        )

        EventBusGatewayPushNotification.create!(user_account: user_account(icn), template_id: template_id)
        StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
      else
        raise 'Failed to fetch ICN'
      end
    rescue => e
      record_notification_send_failure(e, 'Push')
      raise
    end

    private

    def notify_client
      # TODO: Determine if this api key is different
      @notify_client ||= VaNotify::Service.new(Constants::NOTIFY_SETTINGS.api_key)
    end
  end
end
