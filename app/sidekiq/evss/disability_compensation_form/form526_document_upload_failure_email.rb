# frozen_string_literal: true

require 'va_notify/service'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      STATSD_METRIC_PREFIX = 'api.form_526.veteran_notifications.document_upload_failure_email'

      # retry for one day
      sidekiq_options retry: 14

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id, supporting_evidence_attachment_guid = msg['args']

        # Job status records are upserted in the JobTracker module
        # when the retryable_error_handler is called
        form_job_status = Form526JobStatus.find_by(job_id:)
        bgjob_errors = form_job_status.bgjob_errors || {}
        new_error = {
          "#{timestamp.to_i}": {
            caller_method: __method__.to_s,
            timestamp:,
            form526_submission_id:,
            supporting_evidence_attachment_guid:
          }
        }
        form_job_status.update(
          status: Form526JobStatus::STATUS[:exhausted],
          bgjob_errors: bgjob_errors.merge(new_error)
        )

        Rails.logger.warn(
          'Form526DocumentUploadFailureEmail retries exhausted',
          {
            job_id:,
            timestamp:,
            form526_submission_id:,
            error_class:,
            error_message:,
            supporting_evidence_attachment_guid:
          }
        )

        StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted")
      rescue => e
        Rails.logger.error(
          'Failure in Form526DocumentUploadFailureEmail#sidekiq_retries_exhausted',
          {
            job_id:,
            messaged_content: e.message,
            submission_id: form526_submission_id,
            supporting_evidence_attachment_guid:,
            pre_exhaustion_failure: {
              error_class:,
              error_message:
            }
          }
        )
        raise e
      end

      def perform(form526_submission_id, supporting_evidence_attachment_guid)
        super(form526_submission_id)
        submission = Form526Submission.find(form526_submission_id)

        with_tracking('Form526DocumentUploadFailureEmail', submission.saved_claim_id, form526_submission_id) do
          @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.benefits_disability.api_key)
          send_notification_mailer(submission, supporting_evidence_attachment_guid)

          StatsD.increment("#{STATSD_METRIC_PREFIX}.success")
        end
      rescue => e
        retryable_error_handler(e)
      end

      private

      def send_notification_mailer(submission, supporting_evidence_attachment_guid)
        form_attachment = SupportingEvidenceAttachment.find_by!(guid: supporting_evidence_attachment_guid)

        # We need to obscure the original filename since it may contain PII
        obscured_filename = form_attachment.obscured_filename

        email_address = submission.veteran_email_address
        first_name = submission.get_first_name
        date_submitted = submission.format_creation_time_for_mailers
        @notify_client.send_email(
          email_address:,
          template_id: mailer_template_id,
          personalisation: { first_name:, filename: obscured_filename, date_submitted: }
        )

        Rails.logger.info(
          'Form526DocumentUploadFailureEmail notification dispatched',
          {
            obscured_filename:,
            form526_submission_id: submission.id,
            supporting_evidence_attachment_guid:,
            timestamp: Time.now.utc
          }
        )
      end

      def mailer_template_id
        Settings.vanotify.services
                .benefits_disability.template_id.form526_document_upload_failure_notification_template_id
      end

      def retryable_error_handler(error)
        super(error)
        raise error
      end
    end
  end
end
