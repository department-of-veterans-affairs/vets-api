# frozen_string_literal: true

module BGS
  class DependentV2Service
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
                :uuid,
                :file_number

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
      @va_profile_email = user.va_profile_email
    end

    def get_dependents
      return { persons: [] } if participant_id.blank?

      service.claimant.find_dependents_by_participant_id(participant_id, ssn) || { persons: [] }
    end

    def submit_686c_form(claim)
      Rails.logger.info('BGS::DependentV2Service running!', { user_uuid: uuid, saved_claim_id: claim.id, icn: })

      InProgressForm.find_by(form_id: BGS::SubmitForm686cV2Job::FORM_ID, user_uuid: uuid)&.submission_processing!

      encrypted_vet_info = KmsEncrypted::Box.new.encrypt(get_form_hash_686c.to_json)
      submit_pdf_job(claim:, encrypted_vet_info:)

      if claim.submittable_686? || claim.submittable_674?
        submit_form_job_id = submit_to_standard_service(claim:, encrypted_vet_info:)
        Rails.logger.info('BGS::DependentV2Service succeeded!', { user_uuid: uuid, saved_claim_id: claim.id, icn: })
      end

      {
        submit_form_job_id:
      }
    rescue => e
      Rails.logger.warn('BGS::DependentV2Service#submit_686c_form method failed!', { user_uuid: uuid, saved_claim_id: claim.id, icn:, error: e.message }) # rubocop:disable Layout/LineLength
      log_exception_to_sentry(e, { icn:, uuid: }, { team: Constants::SENTRY_REPORTING_TEAM })

      raise e
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def submit_pdf_job(claim:, encrypted_vet_info:)
      if Flipper.enabled?(:dependents_claims_evidence_api_upload)
        # TODO: implement upload using the claims_evidence_api module
        Rails.logger.debug('BGS::DependentV2Service#submit_pdf_job Claims Evidence Upload not implemented!',
                           { claim_id: claim.id })
        return
      end

      Rails.logger.debug('BGS::DependentV2Service#submit_pdf_job called to begin VBMS::SubmitDependentsPdfJob',
                         { claim_id: claim.id })
      VBMS::SubmitDependentsPdfV2Job.perform_sync(
        claim.id,
        encrypted_vet_info,
        claim.submittable_686?,
        claim.submittable_674?
      )
      # This is now set to perform sync to catch errors and proceed to CentralForm submission in case of failure
    rescue => e
      # This indicated the method failed in this job method call, so we submit to Lighthouse Benefits Intake
      Rails.logger.warn('DependentV2Service#submit_pdf_job method failed, submitting to Lighthouse Benefits Intake', { saved_claim_id: claim.id, icn:, error: e }) # rubocop:disable Layout/LineLength
      submit_to_central_service(claim:)

      raise e
    end

    def submit_to_standard_service(claim:, encrypted_vet_info:)
      if claim.submittable_686?
        BGS::SubmitForm686cV2Job.perform_async(
          uuid, icn, claim.id, encrypted_vet_info
        )
      else
        BGS::SubmitForm674V2Job.perform_async(
          uuid, icn, claim.id, encrypted_vet_info
        )
      end
    end

    def submit_to_central_service(claim:)
      vet_info = JSON.parse(claim.form)['dependents_application']
      vet_info.merge!(get_form_hash_686c) unless vet_info['veteran_information']

      user = BGS::SubmitForm686cV2Job.generate_user_struct(vet_info)
      Lighthouse::BenefitsIntake::SubmitCentralForm686cV2Job.perform_async(
        claim.id,
        KmsEncrypted::Box.new.encrypt(vet_info.to_json),
        KmsEncrypted::Box.new.encrypt(user.to_h.to_json)
      )
    end

    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    def get_form_hash_686c
      # include ssn in call to BGS for mocks
      bgs_person = service.people.find_person_by_ptcpnt_id(participant_id, ssn) || service.people.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
      @file_number = bgs_person[:file_nbr]
      # BGS's file number is supposed to be an eight or nine-digit string, and
      # our code is built upon the assumption that this is the case. However,
      # we've seen cases where BGS returns a file number with dashes
      # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
      # the dashes and proceed with form submission.
      @file_number = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/

      # The `validate_*!` calls below will raise errors if we have an invalid
      # file number, or if the file number and SSN don't match. Even if this is
      # the case, we still want to submit a PDF to the veteran's VBMS eFolder.
      # This is because we are currently relying on the presence of a PDF and
      # absence of a BGS-established claim to identify cases where Form 686c-674
      # submission failed.

      generate_hash_from_details
    end

    def generate_hash_from_details
      {
        'veteran_information' => {
          'full_name' => {
            'first' => first_name,
            'middle' => middle_name,
            'last' => last_name
          },
          'common_name' => common_name,
          'va_profile_email' => @va_profile_email,
          'email' => email,
          'participant_id' => participant_id,
          'ssn' => ssn,
          'va_file_number' => file_number,
          'birth_date' => birth_date,
          'uuid' => uuid,
          'icn' => icn
        }
      }
    end
  end
end
