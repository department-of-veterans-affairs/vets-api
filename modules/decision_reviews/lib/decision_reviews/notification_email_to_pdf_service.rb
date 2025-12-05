# frozen_string_literal: true

module DecisionReviews
  # Simplified service that uses PDF templates with stamped personalization
  class NotificationEmailToPdfService
    TEMPLATE_TYPES = {
      hlr_form_failure: 'hlr_form_failure',
      sc_form_failure: 'sc_form_failure',
      sc_4142_failure: 'sc_4142_failure',
      sc_evidence_failure: 'sc_evidence_failure',
      nod_form_failure: 'nod_form_failure',
      nod_evidence_failure: 'nod_evidence_failure'
    }.freeze

    # Initialize with a DecisionReviewNotificationAuditLog record
    def initialize(audit_log)
      raise ArgumentError, 'audit_log is required' if audit_log.nil?

      extract_from_audit_log(audit_log)
      validate_template_type!
    end

    def generate_pdf
      stamper = PdfTemplateStamper.new(template_type: @template_type)

      pdf_binary = stamper.stamp_personalized_data(
        first_name: @first_name,
        submission_date: @submission_date,
        email_address: @email_address,
        sent_date: @sent_date,
        evidence_filename: @evidence_filename
      )

      save_to_file(pdf_binary)
    end

    private

    def extract_from_audit_log(audit_log)
      payload = parse_payload(audit_log.payload)
      reference = audit_log.reference

      # Extract template type from reference (format: "HLR-form-uuid" or "SC-evidence-uuid")
      @template_type = determine_template_type(reference)

      # Extract email address and sent date from payload
      @email_address = payload['to'] || payload[:to]
      @sent_date = parse_date(payload['sent_at'] || payload[:sent_at])

      # Look up submission to get first_name, submission_date, and evidence_filename
      submission_data = fetch_submission_data(reference)
      @first_name = submission_data[:first_name]
      @submission_date = submission_data[:submission_date]
      @evidence_filename = submission_data[:evidence_filename]
    end

    def parse_payload(payload)
      payload.is_a?(String) ? JSON.parse(payload) : payload
    end

    def determine_template_type(reference)
      # Reference format: "HLR-form-uuid", "SC-evidence-uuid", "NOD-secondary_form-uuid"
      parts = reference.split('-')
      appeal_type = parts[0]&.downcase # hlr, sc, nod
      failure_type = parts[1] # form, evidence, secondary_form

      case failure_type
      when 'form'
        "#{appeal_type}_form_failure"
      when 'evidence'
        "#{appeal_type}_evidence_failure"
      when 'secondary_form'
        "#{appeal_type}_4142_failure"
      else
        raise ArgumentError, "Unable to determine template type from reference: #{reference}"
      end
    end

    def parse_date(date_string)
      return nil unless date_string

      Time.zone.parse(date_string)
    rescue ArgumentError
      nil
    end

    def fetch_submission_data(reference)
      # Extract UUID from reference (format: "HLR-form-uuid" or "SC-evidence-uuid")
      uuid = reference.split('-', 3).last

      # Find the submission (required)
      submission = AppealSubmission.find_by(submitted_appeal_uuid: uuid)
      raise ArgumentError, "AppealSubmission not found for UUID: #{uuid}" unless submission

      {
        first_name: submission.get_mpi_profile&.given_names&.first || 'Veteran',
        submission_date: submission.created_at,
        evidence_filename: extract_evidence_filename(reference, submission)
      }
    end

    def extract_evidence_filename(reference, submission)
      # Only fetch evidence filename for evidence failure emails
      return nil unless reference.include?('-evidence-')

      # Find the upload associated with this submission
      upload = submission.appeal_submission_uploads.order(created_at: :desc).first

      return upload.masked_attachment_filename if upload&.masked_attachment_filename

      # If we can't find the evidence filename for an evidence failure, raise an error
      raise ArgumentError, "Evidence filename not found for submission UUID: #{submission.submitted_appeal_uuid}"
    end

    def validate_template_type!
      return if TEMPLATE_TYPES.value?(@template_type)

      raise ArgumentError, "Invalid template_type: #{@template_type}.
                            Must be one of: #{TEMPLATE_TYPES.values.join(', ')}"
    end

    def save_to_file(pdf_binary)
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/dr_email_#{SecureRandom.hex(4).upcase}.pdf"

      File.binwrite(file_path, pdf_binary)
      file_path
    end
  end
end
