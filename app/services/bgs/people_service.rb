# frozen_string_literal: true

module BGS
  class PeopleService < BaseService
    class VAFileNumberNotFound < StandardError; end

    def find_person_by_participant_id
      response = @service.people.find_person_by_ptcpnt_id(@user.participant_id, @user.ssn)

      raise VAFileNumberNotFound if response.nil?

      response
    rescue VAFileNumberNotFound => e
      report_no_va_file_user(e)

      {}
    end

    private

    def report_no_va_file_user(e)
      report_error(e)

      PersonalInformationLog.create(
        error_class: e,
        data: {
          user: {
            uuid: @user.uuid,
            edipi: @user.edipi,
            ssn: @user.ssn,
            participant_id: @user.participant_id
          }
        }
      )
    end
  end
end
