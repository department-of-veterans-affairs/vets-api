# frozen_string_literal: true

require 'claims_evidence_api/uploader'
require 'dependents/monitor'
require 'vets/shared_logging'

module BGS
  class DependentService
    include Vets::SharedLogging

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

    attr_accessor :notification_email

    STATS_KEY = 'bgs.dependent_service'

    class PDFSubmissionError < StandardError; end
    class BgsServicesError < StandardError; end

    # Initialize service with a user-like object.
    # Copies identifying fields onto the service instance for later use
    # when interacting with BGS and building submission payloads.
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
      @notification_email = get_user_email(user)
    end

    # Retrieve dependents for the veteran from BGS.
    # Returns a Hash with :persons => [] (array) for consistent downstream processing.
    # Falls back to an empty response when participant_id is blank or the BGS response
    # does not include dependents.
    def get_dependents
      backup_response = { persons: [] }
      return backup_response if participant_id.blank?

      response = service.claimant.find_dependents_by_participant_id(participant_id, ssn)
      if response.presence && response[:persons]
        # When only one dependent exists, BGS returns a Hash instead of an Array
        # Ensure persons is always an array for consistent processing
        response[:persons] = [response[:persons]] if response[:persons].is_a?(Hash)
        response
      else
        backup_response
      end
    end

    # Top-level orchestration for submitting a 686c/674 dependents form.
    # - Ensures notification email is set (prefers VA profile email, falls back to form email)
    # - Builds and encrypts veteran info
    # - Submits PDFs to ClaimsEvidenceApi (VBMS) and then attempts standard BGS submission
    # - If PDF submission fails, falls back to central submission flow
    # Returns a hash containing the enqueued job id for the BGS submit job when applicable.
    def submit_686c_form(claim)
      # Set email for BGS service and notification emails from form email if va_profile_email is not available
      # Form email is required
      if @notification_email.nil?
        form = claim.parsed_form
        @notification_email = form&.dig('dependents_application', 'veteran_contact_information', 'email_address')
      end

      @monitor = init_monitor(claim&.id)
      @monitor.track_event('info', 'BGS::DependentService running!', "#{STATS_KEY}.start")

      InProgressForm.find_by(form_id: BGS::SubmitForm686cV2Job::FORM_ID, user_uuid: uuid)&.submission_processing!

      encrypted_vet_info = setup_vet_info(claim)
      submit_pdf_job(claim:)

      if claim.submittable_686? || claim.submittable_674?
        submit_form_job_id = submit_to_standard_service(claim:, encrypted_vet_info:)
        @monitor.track_event('info', 'BGS::DependentService succeeded!', "#{STATS_KEY}.success")
      end

      { submit_form_job_id: }
    rescue PDFSubmissionError
      # If ClaimsEvidenceApi (PDF upload) fails, use central submission path.
      submit_to_central_service(claim:, encrypted_vet_info:)
    rescue => e
      # Log and re-raise unexpected errors for caller to handle.
      log_bgs_errors(e)
      raise e
    end

    private

    # Build, attach to claim, and encrypt veteran information to be sent with the form.
    # Returns the encrypted JSON string.
    def setup_vet_info(claim)
      vet_info = get_form_hash_686c
      claim.add_veteran_info(vet_info)

      KmsEncrypted::Box.new.encrypt(vet_info.to_json)
    end

    # Construct the BGS service client for subsequent remote calls.
    # Uses the veteran's ICN and external_key for identification.
    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    # Centralized BGS error logging/tracking wrapper for visibility in monitoring.
    # Emits a monitor event with sanitized error details and increments metrics when configured.
    def log_bgs_errors(error)
      increment_non_validation_error(error) if Flipper.enabled?(:va_dependents_bgs_extra_error_logging)

      # Temporarily logging a few iterations of status code to see what BGS returns in the error
      @monitor.track_event(
        'warn', 'BGS::DependentService#submit_686c_form method failed!',
        "#{STATS_KEY}.failure",
        {
          error: error.message,
          status: error.try(:status) || 'no status',
          status_code: error.try(:status_code) || 'no status code',
          code: error.try(:code) || 'no code'
        }
      )
    end

    # Inspect nested error messages for common HTTP error types and increment StatsD counters.
    # This isolates transient BGS HTTP status conditions for easier alerting.
    def increment_non_validation_error(error)
      error_messages = ['HTTP error (302)', 'HTTP error (500)', 'HTTP error (502)', 'HTTP error (504)']
      error_type_map = {
        'HTTP error (302)' => '302',
        'HTTP error (500)' => '500',
        'HTTP error (502)' => '502',
        'HTTP error (504)' => '504'
      }
      nested_error_message = error.cause&.message

      error_type = error_messages.find do |et|
        nested_error_message&.include?(et)
      end

      if error_type.present?
        error_status = error_type_map[error_type]
        StatsD.increment("#{STATS_KEY}.non_validation_error.#{error_status}", tags: ["form_id:#{BGS::SubmitForm686cV2Job::FORM_ID}"])
      end
    end

    # Build a folder identifier for Claims Evidence API uploads.
    # Chooses the first available identifier from ssn, participant_id, or icn.
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

    # Lazily construct a ClaimsEvidenceApi uploader scoped to the folder identifier.
    def claims_evidence_uploader
      @ce_uploader ||= ClaimsEvidenceApi::Uploader.new(folder_identifier)
    end

    # Orchestrate PDF submission to Claims Evidence (VBMS).
    # - Upload main claim PDF(s)
    # - Upload attachment PDFs
    # Tracks progress via monitor and raises PDFSubmissionError on failure so caller can handle fallback.
    def submit_pdf_job(claim:)
      @monitor = init_monitor(claim&.id)
      @monitor.track_event('info', 'BGS::DependentService#submit_pdf_job called to begin ClaimsEvidenceApi::Uploader',
                           "#{STATS_KEY}.submit_pdf.begin")
      form_id = submit_claim_via_claims_evidence(claim)
      submit_attachments_via_claims_evidence(form_id, claim)

      @monitor.track_event('info', 'BGS::DependentService#submit_pdf_job completed',
                           "#{STATS_KEY}.submit_pdf.completed")
    rescue => e
      error = Flipper.enabled?(:dependents_log_vbms_errors) ? e.message : '[REDACTED]'
      @monitor.track_event('warn',
                           'BGS::DependentService#submit_pdf_job failed, submitting to Lighthouse Benefits Intake',
                           "#{STATS_KEY}.submit_pdf.failure", error:)
      raise PDFSubmissionError
    end

    # Upload the primary claim PDF(s) for 686C and 674 forms via ClaimsEvidenceApi.
    # Returns the form_id used for subsequent attachments.
    def submit_claim_via_claims_evidence(claim)
      form_id = claim.form_id
      doctype = claim.document_type

      if claim.submittable_686?
        form_id = '686C-674-V2'
        file_path = claim.process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id)
        @monitor.track_event('info', "#{self.class} claims evidence upload of #{form_id} claim_id #{claim.id}",
                             "#{STATS_KEY}.claims_evidence.upload", tags: ["form_id:#{form_id}"])
        claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)
      end

      form_id = submit_674_via_claims_evidence(claim) if claim.submittable_674?

      form_id
    end

    # Special handling for 674 PDFs: multiple student PDFs are uploaded and reference data is updated.
    # Ensures ClaimsEvidenceApi submission contains all students' PDFs and file UUID metadata.
    def submit_674_via_claims_evidence(claim)
      form_id = '21-674-V2'
      doctype = 142

      @monitor.track_event('info', "#{self.class} claims evidence upload of #{form_id} claim_id #{claim.id}",
                           "#{STATS_KEY}.claims_evidence.upload", tags: ["form_id:#{form_id}"])

      form_674_pdfs = []
      claim.parsed_form['dependents_application']['student_information']&.each_with_index do |student, index|
        file_path = claim.process_pdf(claim.to_pdf(form_id:, student:), claim.created_at, form_id, index)
        file_uuid = claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)
        form_674_pdfs << [file_uuid, file_path]
      end

      # When multiple student PDFs exist (form 674), encode references into the submission record.
      if form_674_pdfs.length > 1
        file_uuid = form_674_pdfs.map { |fp| fp[0] }
        submission = claims_evidence_uploader.submission
        submission.update_reference_data(students: form_674_pdfs)
        submission.file_uuid = file_uuid.to_s # set to stringified array
        submission.save
      end

      form_id
    end

    # Upload each persistent attachment via ClaimsEvidenceApi, stamping PDFs and sending them.
    def submit_attachments_via_claims_evidence(form_id, claim)
      Rails.logger.info("BGS::DependentService claims evidence upload of #{form_id} claim_id #{claim.id} attachments")
      stamp_set = [{ text: 'VA.GOV', x: 5, y: 5 }]
      claim.persistent_attachments.each do |pa|
        doctype = pa.document_type
        file_path = PDFUtilities::PDFStamper.new(stamp_set).run(pa.to_pdf, timestamp: pa.created_at)
        claims_evidence_uploader.upload_evidence(claim.id, pa.id, file_path:, form_id:, doctype:)
      end
    end

    # Enqueue the appropriate Sidekiq job to submit to the standard BGS service (686c or 674).
    def submit_to_standard_service(claim:, encrypted_vet_info:)
      if claim.submittable_686?
        BGS::SubmitForm686cV2Job.perform_async(
          uuid, claim.id, encrypted_vet_info
        )
      else
        BGS::SubmitForm674V2Job.perform_async(
          uuid, claim.id, encrypted_vet_info
        )
      end
    end

    # Fallback submission path that sends the encrypted vet info to the central intake job.
    # Decrypts the previously encrypted vet_info and generates the user struct required by central job.
    def submit_to_central_service(claim:, encrypted_vet_info:)
      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))

      user = BGS::SubmitForm686cV2Job.generate_user_struct(vet_info)
      Lighthouse::BenefitsIntake::SubmitCentralForm686cV2Job.perform_async(
        claim.id,
        encrypted_vet_info,
        KmsEncrypted::Box.new.encrypt(user.to_h.to_json)
      )
    end

    # Build an external key used for BGS client identification.
    # Prefer the user's common_name, fall back to email, and truncate to max allowed length.
    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    # Retrieve veteran identifiers from BGS and compose the hash used in 686C submissions.
    # - Attempts lookup by participant_id then SSN
    # - Extracts and normalizes va file number when present
    # - Logs and continues on BGS failures
    # Additional notes on this method can be found in app/services/bgs/dependents_veteran_identifiers.md
    def get_form_hash_686c
      begin
        #  SSN is required in test/dev environments but unnecessary in production
        #  This will be fixed in an upcoming refactor by @TaiWilkin

        bgs_person = lookup_bgs_person

        # Safely extract file number from BGS response as an instance variable for later use;
        # For more details on why this matters, see dependents_veteran_identifiers.md
        # The short version is that we need the file number to be present for RBPS, but we are retrieving by PID.
        if bgs_person.respond_to?(:[]) && bgs_person[:file_nbr].present?
          @file_number = bgs_person[:file_nbr]
        else
          @monitor.track_event('warn',
                               'BGS::DependentService#get_form_hash_686c missing bgs_person file_nbr',
                               "#{STATS_KEY}.file_number.missing",
                               { bgs_person_present: bgs_person.present? ? 'yes' : 'no' })
          @file_number = nil
        end

        # Normalize file numbers that are returned in dashed SSN format (XXX-XX-XXXX).
        # BGS's file number is supposed to be an eight or nine-digit string, and
        # our code is built upon the assumption that this is the case. However,
        # we've seen cases where BGS returns a file number with dashes
        # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
        # the dashes and proceed with form submission.
        @file_number = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/

      # This rescue could be hit if BGS is down or unreachable when trying to run find_person_by_ptcpnt_id()
      # It could also be hit if the file number is invalid or missing. We log and continue since we can
      # fall back to using Lighthouse and want to still generate the PDF.
      rescue
        @monitor.track_event('warn',
                             'BGS::DependentService#get_form_hash_686c failed',
                             "#{STATS_KEY}.get_form_hash.failure", { error: 'Could not retrieve file number from BGS' })
      end

      generate_hash_from_details
    end

    # Lookup BGS person record by participant_id (preferred) or SSN (fallback)
    def lookup_bgs_person
      bgs_person = service.people.find_person_by_ptcpnt_id(participant_id, ssn)

      if bgs_person.present?
        @monitor.track_event('info', 'BGS::DependentService#get_form_hash_686c found bgs_person by PID',
                             "#{STATS_KEY}.find_by_participant_id")
      else
        bgs_person = service.people.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
        @monitor.track_event('info', 'BGS::DependentService#get_form_hash_686c found bgs_person by ssn',
                             "#{STATS_KEY}.find_by_ssn")
      end

      bgs_person
    end

    # Compose the final payload hash used by submission jobs.
    # Ensures minimal fields are present and that middle name is omitted only when nil
    # to avoid schema validation issues.
    def generate_hash_from_details
      full_name = { 'first' => first_name, 'last' => last_name }
      full_name['middle'] = middle_name unless middle_name.nil? # nil middle name breaks prod validation
      # Sometimes BGS will return a 502 (Bad Gateway) when trying to find a person by participant id or ssn.
      # Given this a rare occurrence and almost always file number is the same as ssn, we'll set file number
      # to ssn as a backup.
      {
        'veteran_information' => {
          'full_name' => full_name,
          'common_name' => common_name,
          'va_profile_email' => @notification_email,
          'email' => email,
          'participant_id' => participant_id,
          'ssn' => ssn,
          'va_file_number' => file_number || ssn,
          'birth_date' => birth_date,
          'uuid' => uuid,
          'icn' => icn
        }
      }
    end

    # Attempt to retrieve the VA profile email for notifications. If profile lookup fails,
    # log the event and return nil so callers can fall back to form-supplied email.
    def get_user_email(user)
      # Safeguard for when VAProfileRedis::V2::ContactInformation.for_user fails in app/models/user.rb
      # Failure is expected occasionally due to 404 errors from the redis cache
      # New users, users that have not logged on in over a month, users who created an account on web,
      # and users who have not visited their profile page will need to obtain/refresh VAProfile_ID
      # Originates here: lib/va_profile/contact_information/v2/service.rb
      user.va_profile_email
    rescue => e
      # We don't have a claim id accessible yet
      @monitor = init_monitor(nil)
      @monitor.track_event('warn', 'BGS::DependentService#get_user_email failed to get va_profile_email',
                           "#{STATS_KEY}.get_va_profile_email.failure", { error: e.message })
      nil
    end

    # Initialize or return the monitor instance used for tracking events tied to a saved claim id.
    def init_monitor(saved_claim_id)
      @monitor ||= ::Dependents::Monitor.new(saved_claim_id)
    end
  end
end
