# frozen_string_literal: true

require 'va_notify/service'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      # Placeholder
      VA_NOTIFY_TEMPLATE_ID = 'form_526_document_upload_failed'

      def perform(form_526_submission_id, supporting_evidence_attachment_guid)
        # Placeholder service
        @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
        submission = Form526Submission.find(form_526_submission_id)

        email_address = submission.get_email_address
        first_name = submission.get_first_name
        date_submitted = submission.get_formatted_creation_time

        form_attachment = SupportingEvidenceAttachment.find_by!(guid: supporting_evidence_attachment_guid)
        # We need to obscure the original filename since it may contain PII and someone other than the veteran could
        # potentially read the email
        filename = form_attachment.obscured_filename

        @notify_client.send_email(
          email_address:,
          template_id: VA_NOTIFY_TEMPLATE_ID,
          personalisation: {
            first_name:,
            filename:,
            date_submitted:
          }
        )
      end
    end
  end
end
