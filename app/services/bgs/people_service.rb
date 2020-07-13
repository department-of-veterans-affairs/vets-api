# frozen_string_literal: true

module BGS
  class PeopleService
    include SentryLogging
    class VaFileNumberNotFound < StandardError; end

    def initialize(current_user)
      @current_user = current_user
    end

    def find_person_by_participant_id
      response = service.people.find_person_by_ptcpnt_id(@current_user.participant_id)

      raise VaFileNumberNotFound if response.nil?

      response
    rescue VaFileNumberNotFound => e
      report_no_va_file_user(e)

      {}
    end

    private

    def report_no_va_file_user(e)
      log_exception_to_sentry(
        e,
        {
          icn: @current_user.icn
        },
        { team: 'eBenefits' }
      )

      PersonalInformationLog.create(
        error_class: e,
        data: {
          user: {
            uuid: @current_user.uuid,
            edipi: @current_user.edipi,
            ssn: @current_user.ssn,
            participant_id: @current_user.participant_id
          }
        }
      )
    end

    def service
      external_key = @current_user.common_name || @current_user.email

      @service ||= BGS::Services.new(
        external_uid: @current_user.icn,
        external_key: external_key
      )
    end
  end
end
