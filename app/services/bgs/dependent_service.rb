# frozen_string_literal: true

module BGS
  class DependentService
    include SentryLogging

    def initialize(user)
      @user = user
    end

    def get_dependents
      service.claimant.find_dependents_by_participant_id(@user.participant_id, @user.ssn)
    end

    def submit_686c_form(claim)
      bgs_person = service.people.find_person_by_ptcpnt_id(@user.participant_id)
      vet_info = VetInfo.new(@user, bgs_person)

      BGS::SubmitForm686cJob.perform_async(@user.uuid, claim.id, vet_info.to_686c_form_hash)
      VBMS::SubmitDependentsPDFJob.perform_async(claim.id, vet_info.to_686c_form_hash)
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
