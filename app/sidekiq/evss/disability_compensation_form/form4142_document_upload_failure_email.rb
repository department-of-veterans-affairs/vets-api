# frozen_string_literal: true

require 'logging/call_location'
require 'va_notify/service'
require 'zero_silent_failures/monitor'

module EVSS
  module DisabilityCompensationForm
    class Form4142DocumentUploadFailureEmail < Job
      STATSD_METRIC_PREFIX = 'api.form_526.veteran_notifications.form4142_upload_failure_email'
      ZSF_DD_TAG_FUNCTION  = '526_form_4142_upload_failure_email_sending'

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
        form526_submission_id = msg['args'].first

        log_info = { job_id:, timestamp:, form526_submission_id:, error_class:, error_message: }

        Rails.logger.warn(
          'Form4142DocumentUploadFailureEmail retries exhausted',
          log_info
        )

        # Job status records are upserted in the JobTracker module
        # when the retryable_error_handler is called
        form_job_status = Form526JobStatus.find_by(job_id:)
        bgjob_errors = form_job_status.bgjob_errors || {}
        new_error = {
          "#{timestamp.to_i}": {
            caller_method: __method__.to_s,
            timestamp:,
            form526_submission_id:
          }
        }

        form_job_status.update(
          status: Form526JobStatus::STATUS[:exhausted],
          bgjob_errors: bgjob_errors.merge(new_error)
        )
      rescue => e
        Rails.logger.error(
          'Failure in Form4142DocumentUploadFailureEmail#sidekiq_retries_exhausted',
          {
            job_id:,
            messaged_content: e.message,
            submission_id: form526_submission_id,
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
        user_account_id = begin
          Form526Submission.find(form526_submission_id).user_account_id
        rescue
          nil
        end
        ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE).log_silent_failure(
          log_info,
          user_account_id,
          call_location:
        )
      end

      def perform(form526_submission_id)
        form526_submission = Form526Submission.find(form526_submission_id)

        with_tracking('Form4142DocumentUploadFailureEmail', form526_submission.saved_claim_id, form526_submission_id) do
          notify_client = VaNotify::Service.new(Settings.vanotify.services.benefits_disability.api_key,
                                                VA_NOTIFY_CALLBACK_OPTIONS)

          email_address = form526_submission.veteran_email_address
          first_name = form526_submission.get_first_name
          date_submitted = form526_submission.format_creation_time_for_mailers

          va_notify_response = notify_client.send_email(
            email_address:,
            template_id: mailer_template_id,
            personalisation: {
              first_name:,
              date_submitted:
            }
          )
          log_info = { form526_submission_id:, timestamp: Time.now.utc, va_notify_response: }
          log_mailer_dispatch(log_info)
        end
      rescue => e
        retryable_error_handler(e)
      end

      private

      def zsf_monitor
        @zsf_monitor ||= ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE)
      end

      def retryable_error_handler(error)
        # Needed to log the error properly in the Sidekiq::Form526JobStatusTracker::JobTracker,
        # which is included near the top of this job's inheritance tree in EVSS::DisabilityCompensationForm::JobStatus
        super(error)
        raise error
      end

      def log_mailer_dispatch(log_info)
        Rails.logger.info('Form4142DocumentUploadFailureEmail notification dispatched', log_info)
        StatsD.increment("#{STATSD_METRIC_PREFIX}.success")
      end

      def mailer_template_id
        Settings.vanotify.services
                .benefits_disability.template_id.form4142_upload_failure_notification_template_id
      end
    end
  end
end
