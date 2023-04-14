# frozen_string_literal: true

module BGS
  class DependentService
    include SentryLogging

    attr_reader :first_name,
                :middle_name,
                :last_name,
                :ssn,
                :birth_date,
                :common_name,
                :email,
                :icn,
                :participant_id,
                :uuid

    def initialize(user)
      @first_name = user.first_name
      @middle_name = user.middle_name
      @last_name = user.last_name
      @ssn = user.ssn
      @uuid = user.uuid
      @birth_date = user.birth_date
      @common_name = user.common_name
      @email = user.email
      @icn = user.icn
      @participant_id = user.participant_id
    end

    def get_dependents
      service.claimant.find_dependents_by_participant_id(participant_id, ssn) || { persons: [] }
    end

    def submit_686c_form(claim)
      bgs_person = service.people.find_person_by_ptcpnt_id(participant_id)

      bgs_person = service.people.find_by_ssn(ssn) if bgs_person.nil? # rubocop:disable Rails/DynamicFindBy

      form_hash_686c = get_form_hash_686c(file_number: bgs_person[:file_nbr].to_s)

      BGS::SubmitForm686cJob.perform_async(uuid, claim.id, form_hash_686c) if claim.submittable_686?

      VBMS::SubmitDependentsPdfJob.perform_async(
        claim.id,
        form_hash_686c,
        claim.submittable_686?,
        claim.submittable_674?
      )
    rescue => e
      log_exception_to_sentry(e, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    def get_form_hash_686c(file_number:)
      {
        'veteran_information' => {
          'full_name' => {
            'first' => first_name,
            'middle' => middle_name,
            'last' => last_name
          },
          'ssn' => ssn,
          'va_file_number' => file_number,
          'birth_date' => birth_date
        }
      }
    end
  end
end
