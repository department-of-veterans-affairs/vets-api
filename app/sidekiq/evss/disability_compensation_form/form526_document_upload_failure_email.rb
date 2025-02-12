# frozen_string_literal: true

require 'logging/call_location'
require 'va_notify/service'
require 'zero_silent_failures/monitor'

module EVSS
  module DisabilityCompensationForm
    class Form526DocumentUploadFailureEmail < Job
      STATSD_METRIC_PREFIX = 'api.form_526.veteran_notifications.document_upload_failure_email'
      ZSF_DD_TAG_FUNCTION = '526_evidence_upload_failure_email_queuing'
      VA_NOTIFY_CALLBACK_OPTIONS = {
        callback_metadata: {
          notification_type: 'error',
          form_number: Form526Submission::FORM_526,
          statsd_tags: { service: Form526Submission::ZSF_DD_TAG_SERVICE, function: ZSF_DD_TAG_FUNCTION }
        }
      }.freeze
      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id, supporting_evidence_attachment_guid = msg['args']

        log_info = { job_id:, timestamp:, form526_submission_id:, error_class:, error_message:,
                     supporting_evidence_attachment_guid: }

        Rails.logger.warn('Form526DocumentUploadFailureEmail retries exhausted', log_info)

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
      ensure
        StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted")

        cl = caller_locations.first
        call_location = Logging::CallLocation.new(ZSF_DD_TAG_FUNCTION, cl.path, cl.lineno)
        zsf_monitor = ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE)
        user_account_id = begin
          Form526Submission.find(form526_submission_id).user_account_id
        rescue
          nil
        end

        zsf_monitor.log_silent_failure(log_info, user_account_id, call_location:)
      end

      def perform(form526_submission_id, supporting_evidence_attachment_guid)
        super(form526_submission_id)

        submission = Form526Submission.find(form526_submission_id)

        with_tracking('Form526DocumentUploadFailureEmail', submission.saved_claim_id, form526_submission_id) do
          send_notification_mailer(submission, supporting_evidence_attachment_guid)
        end
      rescue => e
        retryable_error_handler(e)
      end

      private

      def send_notification_mailer(submission, supporting_evidence_attachment_guid)
        form_attachment = SupportingEvidenceAttachment.find_by!(guid: supporting_evidence_attachment_guid)

        # We need to obscure the original filename as it may contain PII
        obscured_filename = form_attachment.obscured_filename
        email_address = submission.veteran_email_address
        first_name = submission.get_first_name
        date_submitted = submission.format_creation_time_for_mailers

        notify_service_bd = Settings.vanotify.services.benefits_disability
        notify_client = VaNotify::Service.new(notify_service_bd.api_key, VA_NOTIFY_CALLBACK_OPTIONS)
        template_id = notify_service_bd.template_id.form526_document_upload_failure_notification_template_id

        va_notify_response = notify_client.send_email(
          email_address:,
          template_id:,
          personalisation: { first_name:, filename: obscured_filename, date_submitted: }
        )

        log_info = { obscured_filename:, form526_submission_id: submission.id,
                     supporting_evidence_attachment_guid:, timestamp: Time.now.utc, va_notify_response: }

        log_mailer_dispatch(log_info)
      end

      def log_mailer_dispatch(log_info)
        StatsD.increment("#{STATSD_METRIC_PREFIX}.success")

        Rails.logger.info('Form526DocumentUploadFailureEmail notification dispatched', log_info)
      end

      def retryable_error_handler(error)
        super(error)
        raise error
      end
    end
  end
end
