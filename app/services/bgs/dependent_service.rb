# frozen_string_literal: true

module BGS
  class DependentService
    include SentryLogging

    def initialize(user)
      @user = user
    end

    def get_dependents
      service.claimants.find_dependents_by_participant_id(@user.participant_id, @user.ssn)
    end

    def submit_686c_form(payload)
      va_file_number_with_payload = add_va_file_number_to_payload(payload.to_h)


    rescue => e
      report_error(e)
    end

    private

    def service
      external_key = @user.common_name || @user.email

      @service ||= BGS::Services.new(
        external_uid: @user.icn,
        external_key: external_key
      )
    end

    def add_va_file_number_to_payload(payload)
      va_file_number = service.people.find_person_by_ptcpnt_id(@user.participant_id)

      payload[:veteran_contact_information][:va_file_number] = va_file_number[:file_nbr]

      payload
    end

    def veteran_hash
      {
        participant_id: @user.participant_id,
        ssn: @user.ssn,
        first_name: @user.first_name,
        last_name: @user.last_name,
        email: @user.email,
        external_key: @user.common_name || @user.email,
        icn: @user.icn
      }
    end

    def report_error(error)
      log_exception_to_sentry(
        error,
        {
          icn: @user.icn
        },
        { team: 'vfs-ebenefits' }
      )
    end
  end
end
