# frozen_string_literal: true

require 'va_notify/service'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      # Placeholder
      VA_NOTIFY_TEMPLATE_ID = 'form_526_document_upload_failed'

      def perform(form_526_submission_id, supporting_evidence_attachment_guid)
        @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
        submission = Form526Submission.find(form_526_submission_id)

        email_address = submission.get_email_address
        first_name = submission.get_first_name
        date_submitted = submission.created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')

        form_attachment = SupportingEvidenceAttachment.find_by!(guid: supporting_evidence_attachment_guid)
        filename = obscure_filename(form_attachment)

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

      private

      def obscure_filename(form_attachment)
        raw_filename = form_attachment.original_filename
        extension = raw_filename[/\.\S*$/]
        filename = raw_filename.gsub(/\.\S*$/, '')

        # Obfuscate filenames longer than five characters
        if filename.length > 5
          obfuscated_portion = filename[3..-3].gsub(/[a-zA-Z]/, '*')
          filename[0..2] + obfuscated_portion + filename[-2..] + extension
        else
          raw_filename
        end
      end
    end
  end
end
