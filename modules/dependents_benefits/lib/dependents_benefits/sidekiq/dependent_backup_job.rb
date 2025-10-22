# frozen_string_literal: true

require 'central_mail/service'
require 'benefits_intake_service/service'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_info'
require 'simple_forms_api_submission/metadata_validator'

module DependentsBenefits::Sidekiq
  class DependentBackupJob < DependentSubmissionJob
    include Sidekiq::Job

    FOREIGN_POSTALCODE = '00000'

    ##
    # Service-specific submission logic for Lighthouse upload
    # @return [ServiceResponse] Must respond to success? and error methods
    def submit_to_service
      saved_claim.add_veteran_info(user_data)
      get_files_from_claim
      upload_to_lh
    rescue => e
      DependentsBenefits::ServiceResponse.new(status: false, error: e)
    ensure
      cleanup_file_paths
    end

    def handle_permanent_failure(msg, error)
      @claim_id = msg['args'].first
      send_failure_notification
      monitor.log_silent_failure_avoided({ claim_id:, error: })
    rescue => e
      # Last resort if notification fails
      monitor.log_silent_failure({ claim_id:, error: e })
    end

    # Atomic updates prevent partial state corruption
    def handle_job_success
      ActiveRecord::Base.transaction do
        parent_group.with_lock do
          mark_submission_succeeded # update attempt and submission records (ie FormSubmission)

          # update parent claim group status - overwrite failure since we're in backup job
          # the parent group is marked as processing to indicate it hasn't reached VBMS yet
          mark_parent_group_processing
          # notify user of acceptance by the service - final success will be sent after VBMS is reached
          send_in_progress_notification
        end
      end
    rescue => e
      monitor.track_submission_error('Error handling job success', 'success_failure', error: e)
    end

    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(form_path)
      attachment_paths.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    end

    private

    def get_files_from_claim
      # process the main pdf record and the attachments as we would for a vbms submission
      form_674_paths = []
      form_686c_path = nil
      DependentsBenefits::ClaimProcessor.new(saved_claim.id, proc_id).collect_child_claims.each do |claim|
        pdf_path = process_pdf(claim.to_pdf, claim.created_at, claim.form_id)

        if claim.form_id == DependentsBenefits::ADD_REMOVE_DEPENDENT
          form_686c_path = pdf_path
        else
          form_674_paths << pdf_path
        end
      end

      # set main form_path to be first 674 in array if needed
      @form_path = form_686c_path.presence || form_674_paths.shift

      # prepend any 674s to attachments
      @attachment_paths = form_674_paths + saved_claim.persistent_attachments.map do |pa|
        process_pdf(pa.to_pdf, saved_claim.created_at)
      end
    end

    def upload_to_lh
      lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
      @uuid = lighthouse_service.uuid
      monitor.track_backup_job_info('DependentBackupJob Lighthouse Submission Attempt',
                                    'lighthouse.attempt', uuid:, claim_id:)
      response = lighthouse_service.upload_form(
        main_document: split_file_and_path(form_path),
        attachments: attachment_paths.map(&method(:split_file_and_path)),
        form_metadata: generate_metadata_lh
      )

      monitor.track_backup_job_info('DependentBackupJob Lighthouse Submission Successful',
                                    'lighthouse.success', uuid:, claim_id:)

      response
    end

    def process_pdf(pdf_path, timestamp = nil, form_id = nil)
      stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(
        text: 'VA.GOV', x: 5, y: 5, timestamp:, template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf"
      )
      stamped_path2 = PDFUtilities::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - va.gov Submission', x: 400, y: 770, text_only: true, template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf"
      )
      if form_id.present?
        stamped_pdf_with_form(form_id, stamped_path2, timestamp)
      else
        stamped_path2
      end
    end

    def get_hash_and_pages(file_path)
      {
        hash: Digest::SHA256.file(file_path).hexdigest,
        pages: PdfInfo::Metadata.read(file_path).pages
      }
    end

    def user_zipcode
      address = saved_claim.parsed_form.dig('dependents_application', 'veteran_contact_information', 'veteran_address')
      address['country_name'] == 'USA' ? address['postal_code'] : FOREIGN_POSTALCODE
    end

    def generate_metadata_lh
      veteran_information = user_data['veteran_information']
      {
        veteran_first_name: veteran_information['full_name']['first'],
        veteran_last_name: veteran_information['full_name']['last'],
        file_number: veteran_information['va_file_number'],
        zip: user_zipcode,
        doc_type: saved_claim.form_id,
        claim_date: saved_claim.created_at,
        source: 'va.gov backup dependent claim submission',
        business_line: 'CMP'
      }
    end

    def stamped_pdf_with_form(form_id, path, timestamp)
      PDFUtilities::DatestampPdf.new(path).run(
        text: 'Application Submitted on va.gov',
        x: 400,
        y: 675,
        text_only: true, # passing as text only because we override how the date is stamped in this instance
        timestamp:,
        page_number: %w[686C-674 686C-674-V2].include?(form_id) ? 6 : 0,
        template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf",
        multistamp: true
      )
    end

    def split_file_and_path(path) = { file: path, file_name: path.split('/').last }

    def attachment_paths
      @attachment_paths ||= []
    end

    def form_path = @form_path || nil

    def saved_claim = @saved_claim ||= DependentsBenefits::SavedClaim.find(claim_id)

    def uuid = @uuid || nil

    def find_or_create_form_submission
      @submission = Lighthouse::Submission.find_or_create_by!(saved_claim_id: saved_claim.id) do |submission|
        submission.assign_attributes({ form_id: saved_claim.form_id, reference_data: saved_claim.to_json })
      end
    end

    def create_form_submission_attempt
      @submission_attempt = Lighthouse::SubmissionAttempt.create(submission:, benefits_intake_uuid: uuid)
    end

    # Service-specific success logic
    # Update submission attempt and form submission records
    def mark_submission_succeeded = submission_attempt&.success!

    # Service-specific failure logic
    # Update submission attempt record only with failure and error details
    def mark_submission_attempt_failed(_exception) = submission_attempt&.fail!

    # Lighthouse submission has no status update, so no-op here
    def mark_submission_failed(_exception) = nil

    # We don't care about parent group status in backup job
    def parent_group_failed? = false
  end
end
