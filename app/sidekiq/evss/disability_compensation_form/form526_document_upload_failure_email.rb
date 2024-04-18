# frozen_string_literal: true

require 'va_notify/service'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      STATSD_SENT_METRIC_KEY = 'api.form_526.veteran_notifications.document_upload_failure_email.success'
      STATSD_EXHAUSTED_METRIC_KEY = 'api.form_526.veteran_notifications.document_upload_failure_email.exhausted'

      # retry for one day
      sidekiq_options retry: 14

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id = msg['args'][0]

        Rails.logger.warn(
          'EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail retries exhausted',
          { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
        )

        StatsD.increment(STATSD_EXHAUSTED_METRIC_KEY)
      rescue => e
        ::Rails.logger.error(
          'Failure in DisabilityCompensationForm::Form526DocumentUploadFailureEmail#sidekiq_retries_exhausted',
          {
            messaged_content: e.message,
            job_id:,
            submission_id: form526_submission_id,
            pre_exhaustion_failure: {
              error_class:,
              error_message:
            }
          }
        )
        raise e
      end

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

        Rails.logger.info(
          'EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail notification dispatched',
          {
            obscured_filename:,
            form526_submission_id:,
            supporting_evidence_attachment_guid: supporting_evidence_attachment_guid,
            timestamp: Time.now.utc
          }
        )

        StatsD.increment(STATSD_SENT_METRIC_KEY)
      rescue => e
        retryable_error_handler(e)
      end
    end

    def retryable_error_handler(error)
      super(error)
      raise error
    end
  end
end
