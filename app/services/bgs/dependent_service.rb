# frozen_string_literal: true

require 'claims_evidence_api/uploader'
require 'dependents/monitor'

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
                :uuid,
                :file_number

    STATS_KEY = 'bgs.dependent_service'

    class PDFSubmissionError < StandardError; end

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
      @monitor = init_monitor(claim&.id)
      @monitor.track_event('info', 'BGS::DependentService running!', "#{STATS_KEY}.start")

      InProgressForm.find_by(form_id: BGS::SubmitForm686cJob::FORM_ID, user_uuid: uuid)&.submission_processing!

      encrypted_vet_info = KmsEncrypted::Box.new.encrypt(get_form_hash_686c.to_json)
      submit_pdf_job(claim:, encrypted_vet_info:)

      if claim.submittable_686? || claim.submittable_674?
        submit_form_job_id = submit_to_standard_service(claim:, encrypted_vet_info:)
        @monitor.track_event('info', 'BGS::DependentService succeeded!', "#{STATS_KEY}.success")
      end

      { submit_form_job_id: }
    rescue PDFSubmissionError
      submit_to_central_service(claim:)
    rescue => e
      @monitor.track_event('warn', 'BGS::DependentService#submit_686c_form method failed!',
                           "#{STATS_KEY}.failure", { error: e.message })
      log_exception_to_sentry(e, { icn:, uuid: }, { team: Constants::SENTRY_REPORTING_TEAM })

      raise e
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def folder_identifier
      fid = 'VETERAN'
      { ssn:, participant_id:, icn: }.each do |k, v|
        if v.present?
          fid += ":#{k.to_s.upcase}:#{v}"
          break
        end
      end

      fid
    end

    def claims_evidence_uploader
      @ce_uploader ||= ClaimsEvidenceApi::Uploader.new(folder_identifier)
    end

    def submit_pdf_job(claim:, encrypted_vet_info:)
      @monitor = init_monitor(claim&.id)
      if Flipper.enabled?(:dependents_claims_evidence_api_upload)
        @monitor.track_event('debug', 'BGS::DependentService#submit_pdf_job called to begin ClaimsEvidenceApi::Uploader',
                             "#{STATS_KEY}.submit_pdf.begin")
        form_id = submit_claim_via_claims_evidence(claim)
        submit_attachments_via_claims_evidence(form_id, claim)
      else
        @monitor.track_event('debug', 'BGS::DependentService#submit_pdf_job called to begin VBMS::SubmitDependentsPdfJob',
                             "#{STATS_KEY}.submit_pdf.begin")
        # This is now set to perform sync to catch errors and proceed to CentralForm submission in case of failure
        VBMS::SubmitDependentsPdfJob.perform_sync(claim.id, encrypted_vet_info, claim.submittable_686?,
                                                  claim.submittable_674?)
      end

      @monitor.track_event('debug', 'BGS::DependentService#submit_pdf_job completed',
                           "#{STATS_KEY}.submit_pdf.completed")
    rescue => e
      @monitor.track_event('warn',
                           'BGS::DependentService#submit_pdf_job failed, submitting to Lighthouse Benefits Intake',
                           "#{STATS_KEY}.submit_pdf.failure", { error: e })
      raise PDFSubmissionError, e.message
    end

    def submit_claim_via_claims_evidence(claim)
      form_id = claim.form_id
      doctype = claim.document_type
      if claim.submittable_686?
        form_id = '686C-674'
        file_path = claim.process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id)
        claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)
      end
      if claim.submittable_674?
        form_id = '21-674'
        doctype = '142'
        claim.process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id)
        claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)
      end

      form_id
    end

    def submit_attachments_via_claims_evidence(form_id, claim)
      stamp_set = [{ text: 'VA.GOV', x: 5, y: 5 }]
      claim.persistent_attachments.each do |pa|
        doctype = pa.document_type
        file_path = PDFUtilities::PDFStamper.new(stamp_set).run(pa.to_pdf, timestamp: pa.created_at)
        claims_evidence_uploader.upload_evidence(claim.id, pa.id, file_path:, form_id:, doctype:)
      end
    end

    def submit_to_standard_service(claim:, encrypted_vet_info:)
      if claim.submittable_686?
        BGS::SubmitForm686cJob.perform_async(
          uuid, icn, claim.id, encrypted_vet_info
        )
      else
        BGS::SubmitForm674Job.perform_async(
          uuid, icn, claim.id, encrypted_vet_info
        )
      end
    end

    def submit_to_central_service(claim:)
      vet_info = JSON.parse(claim.form)['dependents_application']
      vet_info.merge!(get_form_hash_686c) unless vet_info['veteran_information']

      user = BGS::SubmitForm686cJob.generate_user_struct(vet_info)
      Lighthouse::BenefitsIntake::SubmitCentralForm686cJob.perform_async(
        claim.id,
        KmsEncrypted::Box.new.encrypt(vet_info.to_json),
        KmsEncrypted::Box.new.encrypt(user.to_h.to_json)
      )
    rescue => e
      Rails.logger.error("BGS::DependentService failed to submit to central service: #{e.message}")
      # raising the error here causes the user to get a 500 error response
      raise e
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

    def init_monitor(saved_claim_id)
      @monitor ||= ::Dependents::Monitor.new(saved_claim_id)
    end
  end
end
