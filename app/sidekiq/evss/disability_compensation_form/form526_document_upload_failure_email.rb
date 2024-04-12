# frozen_string_literal: true

require 'va_notify/service'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      STATSD_METRIC_KEY = 'api.form_526.document_upload_failure_notification_sent'

      def perform(form526_submission_id, supporting_evidence_attachment_guid)
        @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.benefits_disability.api_key)
        submission = Form526Submission.find(form526_submission_id)

        email_address = submission.get_email_address
        first_name = submission.get_first_name
        date_submitted = submission.get_formatted_creation_time

        template_id = Settings.vanotify.services
                              .benefits_disability.template_id.form526_document_upload_failure_notification_template_id

        form_attachment = SupportingEvidenceAttachment.find_by!(guid: supporting_evidence_attachment_guid)
        # We need to obscure the original filename since it may contain PII
        obscured_filename = form_attachment.obscured_filename

        @notify_client.send_email(
          email_address:,
          template_id:,
          personalisation: {
            first_name:,
            filename: obscured_filename,
            date_submitted:
          }
        )

        Rails.logger.warn(
          'EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail notification dispatched',
          {
            obscured_filename:,
            form526_submission_id:,
            supporting_evidence_attachment_guid:,
            timestamp: Time.now.utc
          }
        )

        StatsD.increment(STATSD_METRIC_KEY)
      end
    end
  end
end
