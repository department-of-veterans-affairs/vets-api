# frozen_string_literal: true

require 'claims_evidence_api/uploader'
require 'dependents/monitor'

module BEP
  class DependentService
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

    STATS_KEY = 'bep.dependent_service'

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
      backup_response = { persons: [] }
      return backup_response if participant_id.blank?

      response = service.claimant.find_dependents_by_participant_id(participant_id, ssn)
      if response.presence && response[:persons]
        # When only one dependent exists, BEP returns a Hash instead of an Array
        # Ensure persons is always an array for consistent processing
        response[:persons] = [response[:persons]] if response[:persons].is_a?(Hash)
        response
      else
        backup_response
      end
    end

    def submit_686c_form(claim)
      @monitor = init_monitor(claim&.id)
      @monitor.track_event('info', 'BEP::DependentService running!', "#{STATS_KEY}.start")

      InProgressForm.find_by(form_id: BEP::SubmitForm686cJob::FORM_ID, user_uuid: uuid)&.submission_processing!

      encrypted_vet_info = KmsEncrypted::Box.new.encrypt(get_form_hash_686c.to_json)
      submit_pdf_job(claim:)

      if claim.submittable_686? || claim.submittable_674?
        submit_form_job_id = submit_to_standard_service(claim:, encrypted_vet_info:)
        @monitor.track_event('info', 'BEP::DependentService succeeded!', "#{STATS_KEY}.success")
      end

      { submit_form_job_id: }
    rescue PDFSubmissionError
      submit_to_central_service(claim:)
    rescue => e
      @monitor.track_event('warn', 'BEP::DependentService#submit_686c_form method failed!',
                           "#{STATS_KEY}.failure", { error: e.message, user_uuid: uuid })
      raise e
    end

    private

    def service
      @service ||= BEP::Services.new(external_uid: icn, external_key:)
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

    def submit_pdf_job(claim:)
      @monitor = init_monitor(claim&.id)
      @monitor.track_event('info', 'BEP::DependentService#submit_pdf_job called to begin ClaimsEvidenceApi::Uploader',
                           "#{STATS_KEY}.submit_pdf.begin")
      form_id = submit_claim_via_claims_evidence(claim)
      submit_attachments_via_claims_evidence(form_id, claim)

      @monitor.track_event('info', 'BEP::DependentService#submit_pdf_job completed',
                           "#{STATS_KEY}.submit_pdf.completed")
    rescue => e
      error = Flipper.enabled?(:dependents_log_vbms_errors) ? e.message : '[REDACTED]'
      @monitor.track_event('warn',
                           'BEP::DependentService#submit_pdf_job failed, submitting to Lighthouse Benefits Intake',
                           "#{STATS_KEY}.submit_pdf.failure", error:)
      raise PDFSubmissionError
    end

    def submit_claim_via_claims_evidence(claim)
      form_id = claim.form_id
      doctype = claim.document_type
      if claim.submittable_686?
        form_id = '686C-674'
        file_path = claim.process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id)
        @monitor.track_event('info', "#{self.class} claims evidence upload of #{form_id} claim_id #{claim.id}",
                             "#{STATS_KEY}.claims_evidence.upload", tags: ["form_id:#{form_id}"])
        claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)
      end

      if claim.submittable_674?
        form_id = '21-674'
        doctype = 142
        claim.process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id)
        @monitor.track_event('info', "#{self.class} claims evidence upload of #{form_id} claim_id #{claim.id}",
                             "#{STATS_KEY}.claims_evidence.upload", tags: ["form_id:#{form_id}"])
        claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)
      end

      form_id
    end

    def submit_attachments_via_claims_evidence(form_id, claim)
      Rails.logger.info("BEP::DependentService claims evidence upload of #{form_id} claim_id #{claim.id} attachments")
      stamp_set = [{ text: 'VA.GOV', x: 5, y: 5 }]
      claim.persistent_attachments.each do |pa|
        doctype = pa.document_type
        file_path = PDFUtilities::PDFStamper.new(stamp_set).run(pa.to_pdf, timestamp: pa.created_at)
        claims_evidence_uploader.upload_evidence(claim.id, pa.id, file_path:, form_id:, doctype:)
      end
    end

    def submit_to_standard_service(claim:, encrypted_vet_info:)
      if claim.submittable_686?
        BEP::SubmitForm686cJob.perform_async(
          uuid, claim.id, encrypted_vet_info
        )
      else
        BEP::SubmitForm674Job.perform_async(
          uuid, claim.id, encrypted_vet_info
        )
      end
    end

    def submit_to_central_service(claim:)
      vet_info = JSON.parse(claim.form)['dependents_application']
      vet_info.merge!(get_form_hash_686c) unless vet_info['veteran_information']

      user = BEP::SubmitForm686cJob.generate_user_struct(vet_info)
      Lighthouse::BenefitsIntake::SubmitCentralForm686cJob.perform_async(
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
      # include ssn in call to BEP for mocks
      bep_person = service.people.find_person_by_ptcpnt_id(participant_id, ssn) || service.people.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
      @file_number = bep_person[:file_nbr]
      # BEP's file number is supposed to be an eight or nine-digit string, and
      # our code is built upon the assumption that this is the case. However,
      # we've seen cases where BEP returns a file number with dashes
      # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
      # the dashes and proceed with form submission.
      @file_number = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/

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
