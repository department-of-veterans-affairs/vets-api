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

    def submit_686c_form(claim)
      va_file_number_with_payload = add_va_file_number_to_payload

      VBMS::SubmitDependentsPDFJob.perform_async(claim.id, va_file_number_with_payload)
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

    def add_va_file_number_to_payload
      va_file_number = service.people.find_person_by_ptcpnt_id(@user.participant_id)

      {
        'veteran_information' => {
          'full_name' => {
            'first' => @user.first_name,
            'middle' => @user.middle_name,
            'last' => @user.last_name # ,
          },
          'ssn' => @user.ssn,
          'va_file_number' => va_file_number[:file_nbr],
          'birth_date' => @user.birth_date
        }
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
