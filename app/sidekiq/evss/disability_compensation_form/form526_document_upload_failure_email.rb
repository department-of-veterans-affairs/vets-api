# frozen_string_literal: true

require 'va_notify/service'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      def perform(form_526_submission_id, supporting_evidence_attachment_guid)
        @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.benefits_disability.api_key)
        submission = Form526Submission.find(form_526_submission_id)

        email_address = submission.get_email_address
        first_name = submission.get_first_name
        date_submitted = submission.get_formatted_creation_time

        template_id = Settings.vanotify.services
                              .benefits_disability.template_id.form526_document_upload_failure_notification_template_id

        form_attachment = SupportingEvidenceAttachment.find_by!(guid: supporting_evidence_attachment_guid)
        # We need to obscure the original filename since it may contain PII and someone other than the veteran could
        # potentially read the email
        filename = form_attachment.obscured_filename

        @notify_client.send_email(
          email_address:,
          template_id:,
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
