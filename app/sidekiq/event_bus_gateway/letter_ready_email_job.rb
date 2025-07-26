# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job

    sidekiq_options retry: 0
    NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
    HOSTNAME_MAPPING = {
      'dev-api.va.gov' => 'dev.va.gov',
      'staging-api.va.gov' => 'staging.va.gov',
      'api.va.gov' => 'www.va.gov'
    }.freeze

    def perform(participant_id, template_id)
      if get_mpi_profile(participant_id)
        response = notify_client.send_email(
          recipient_identifier: { id_value: participant_id, id_type: 'PID' },
          template_id:,
          personalisation: { host: HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
                             first_name: get_first_name_from_participant_id(participant_id) }
        )
        EventBusGatewayNotification.create(user_account: user_account(participant_id), template_id:,
                                           va_notify_id: response.id)
      end
    rescue => e
      record_email_send_failure(e)
    end

    private

    def notify_client
      @notify_client ||= VaNotify::Service.new(NOTIFY_SETTINGS.api_key,
                                               { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' })
    end

    def user_account(participant_id)
      UserAccount.find_by(icn: get_mpi_profile(participant_id).icn)
    end

    def get_bgs_person(participant_id)
      @bgs_person ||= begin
        bgs = BGS::Services.new(external_uid: participant_id, external_key: participant_id)
        person = bgs.people.find_person_by_ptcpnt_id(participant_id)
        raise StandardError, 'Participant ID cannot be found in BGS' if person.nil?

        person
      end
    end

    def get_mpi_profile(participant_id)
      @mpi_profile ||= begin
        person = get_bgs_person(participant_id)
        mpi = MPI::Service.new.find_profile_by_attributes(
          first_name: person[:first_nm].capitalize,
          last_name: person[:last_nm].capitalize,
          birth_date: person[:brthdy_dt].strftime('%Y%m%d'),
          ssn: person[:ssn_nbr]
        )&.profile
        raise 'Failed to fetch MPI profile' if mpi.nil?

        mpi
      end
    end

    def get_first_name_from_participant_id(participant_id)
      person = get_bgs_person(participant_id)
      person[:first_nm].capitalize
    end

    def record_email_send_failure(error)
      error_message = 'LetterReadyEmailJob email error'
      ::Rails.logger.error(error_message, { message: error.message })
      StatsD.increment('event_bus_gateway', tags: ['service:event-bus-gateway', "function: #{error_message}"])
    end
  end
end
