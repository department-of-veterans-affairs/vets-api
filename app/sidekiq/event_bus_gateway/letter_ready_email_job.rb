# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: 0
    NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
    HOSTNAME_MAPPING = {
      'dev-api.va.gov' => 'dev.va.gov',
      'staging-api.va.gov' => 'staging.va.gov',
      'api.va.gov' => 'www.va.gov'
    }.freeze

    def perform(participant_id, template_id)
      notify_client.send_email(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: { host: HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
                           first_name: get_first_name_from_participant_id(participant_id) }
      )
    rescue => e
      record_email_send_failure(e)
    end

    private

    def notify_client
      VaNotify::Service.new(NOTIFY_SETTINGS.api_key)
    end

    def get_first_name_from_participant_id(participant_id)
      bgs = BGS::Services.new(external_uid: participant_id, external_key: participant_id)
      person = bgs.people.find_person_by_ptcpnt_id(participant_id)
      if person
        person[:first_nm].capitalize
      else
        raise StandardError, 'Participant ID cannot be found in BGS'
      end
    end

    def record_email_send_failure(error)
      error_message = 'LetterReadyEmailJob errored'
      ::Rails.logger.error(error_message, { message: error.message })
      StatsD.increment('event_bus_gateway', tags: ['service:event-bus-gateway', "function: #{error_message}"])
    end
  end
end
