# frozen_string_literal: true

require 'sidekiq'
require_relative 'constants'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job

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

    def perform(participant_id, template_id)
      if get_mpi_profile(participant_id)
        response = notify_client.send_email(
          recipient_identifier: { id_value: participant_id, id_type: 'PID' },
          template_id:,
          personalisation: { host: Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
                             first_name: get_first_name_from_participant_id(participant_id) }
        )
        EventBusGatewayNotification.create(user_account: user_account(participant_id), template_id:,
                                           va_notify_id: response.id)
        StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
      end
    rescue => e
      record_email_send_failure(e)
      raise
    end

    private

    def notify_client
      @notify_client ||= VaNotify::Service.new(Constants::NOTIFY_SETTINGS.api_key,
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
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.failure", tags:)
    end
  end
end
