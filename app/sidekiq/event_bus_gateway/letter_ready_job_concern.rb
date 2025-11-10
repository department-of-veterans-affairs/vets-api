# frozen_string_literal: true

module EventBusGateway
  module LetterReadyJobConcern
    extend ActiveSupport::Concern

    private

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

    def get_icn(participant_id)
      get_mpi_profile(participant_id)&.icn
    end

    def record_notification_send_failure(error, job_type)
      error_message = "LetterReady#{job_type}Job #{job_type.downcase} error"
      ::Rails.logger.error(error_message, { message: error.message })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{self.class::STATSD_METRIC_PREFIX}.failure", tags:)
    end

    # Helper method to validate participant data exists before queuing individual jobs
    def validate_participant_data(participant_id)
      get_mpi_profile(participant_id)
    rescue => e
      ::Rails.logger.error("Failed to validate participant data for #{participant_id}", { message: e.message })
      raise
    end

    def user_account(icn)
      UserAccount.find_by(icn:)
    end
  end
end
