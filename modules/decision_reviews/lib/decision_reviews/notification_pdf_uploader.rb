# frozen_string_literal: true

require 'claims_evidence_api/service/files'
require 'claims_evidence_api/folder_identifier'
require 'decision_reviews/notification_email_to_pdf_service'

module DecisionReviews
  # Service to generate and upload notification email PDFs to VBMS
  class NotificationPdfUploader
    # Document type for notification email PDFs
    # TODO: Confirm correct doctype code with VBMS team
    NOTIFICATION_EMAIL_DOCTYPE = 10 # Using default doctype for now

    class UploadError < StandardError; end

    attr_reader :audit_log, :appeal_submission

    def initialize(audit_log)
      @audit_log = audit_log
      @appeal_submission = find_appeal_submission
    end

    # Generate PDF and upload to VBMS, updating audit_log with results
    # @return [String] VBMS file_uuid
    # @raise [UploadError] if upload fails
    def upload_to_vbms
      pdf_path = generate_pdf
      file_uuid = upload_pdf(pdf_path)

      update_audit_log_success(file_uuid)
      file_uuid
    rescue => e
      update_audit_log_failure(e)
      raise UploadError, "Failed to upload notification PDF: #{e.message}"
    ensure
      cleanup_pdf(pdf_path)
    end

    private

    def generate_pdf
      pdf_service = NotificationEmailToPdfService.new(@audit_log)
      pdf_service.generate_pdf
    end

    def upload_pdf(pdf_path)
      folder_identifier = build_folder_identifier
      provider_data = build_provider_data

      service = ClaimsEvidenceApi::Service::Files.new
      service.folder_identifier = folder_identifier

      response = service.upload(pdf_path, provider_data:)
      file_uuid = response.body['uuid']

      Rails.logger.info('DecisionReviews::NotificationPdfUploader uploaded PDF',
                        notification_id: @audit_log.notification_id,
                        reference: @audit_log.reference,
                        file_uuid:,
                        appeal_type: @appeal_submission.type_of_appeal)

      file_uuid
    end

    def build_folder_identifier
      icn = @appeal_submission.user_account.icn
      # icn = "1012667122V019349" # DO NOT COMMIT, FOR LOCAL TESTING ONLY
      # binding.pry
      ClaimsEvidenceApi::FolderIdentifier.generate('VETERAN', 'ICN', icn)
    end

    def build_provider_data
      {
        contentSource: ClaimsEvidenceApi::CONTENT_SOURCE,
        dateVaReceivedDocument: format_date(@audit_log.created_at),
        documentTypeId: NOTIFICATION_EMAIL_DOCTYPE
      }
    end

    def format_date(datetime)
      DateTime.parse(datetime.to_s).in_time_zone(ClaimsEvidenceApi::TIMEZONE).strftime('%Y-%m-%d')
    end

    def find_appeal_submission
      uuid = @audit_log.reference.split('-', 3).last
      AppealSubmission.find_by!(submitted_appeal_uuid: uuid)
    rescue ActiveRecord::RecordNotFound => e
      raise UploadError, "AppealSubmission not found for UUID: #{uuid} - #{e.message}"
    end

    def update_audit_log_success(file_uuid)
      @audit_log.update!(
        pdf_uploaded_at: Time.current,
        vbms_file_uuid: file_uuid,
        pdf_upload_error: nil
      )
    end

    def update_audit_log_failure(error)
      @audit_log.update!(
        pdf_upload_attempt_count: (@audit_log.pdf_upload_attempt_count || 0) + 1,
        pdf_upload_error: error.message
      )
    end

    def cleanup_pdf(pdf_path)
      File.delete(pdf_path) if pdf_path && File.exist?(pdf_path)
    end
  end
end
