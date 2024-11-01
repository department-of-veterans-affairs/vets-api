# frozen_string_literal: true

require 'va_notify/service'
require 'zero_silent_failures/monitor'

module EVSS
  module DisabilityCompensationForm
    class Form0781DocumentUploadFailureEmail < Job
      STATSD_METRIC_PREFIX = 'api.form_526.veteran_notifications.form0781_upload_failure_email'
      ZSF_DD_TAG_FUNCTION = '526_form_0781_failure_email_queuing'

      # retry for one day
      sidekiq_options retry: 14

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id = msg['args'].first

        log_info = { job_id:, timestamp:, form526_submission_id:, error_class:, error_message: }

        Rails.logger.warn('Form0781DocumentUploadFailureEmail retries exhausted', log_info)

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
          'Failure in Form0781DocumentUploadFailureEmail#sidekiq_retries_exhausted',
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
        call_location = ZeroSilentFailures::Monitor::CallLocation.new(ZSF_DD_TAG_FUNCTION, cl.path, cl.lineno)
        zsf_monitor = ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE)
        user_account_id = begin
          Form526Submission.find(form526_submission_id).user_account_id
        rescue
          nil
        end

        zsf_monitor.log_silent_failure(log_info, user_account_id, call_location:)
      end

      def perform(form526_submission_id)
        submission = Form526Submission.find(form526_submission_id)

        with_tracking('Form0781DocumentUploadFailureEmail', submission.saved_claim_id, form526_submission_id) do
          send_notification_mailer(submission)
        end
      rescue => e
        retryable_error_handler(e)
      end

      private

      def retryable_error_handler(error)
        # Needed to log the error properly in the Sidekiq::Form526JobStatusTracker::JobTracker,
        # which is included near the top of this job's inheritance tree in EVSS::DisabilityCompensationForm::JobStatus
        super(error)
        raise error
      end

      def send_notification_mailer(submission)
        email_address = submission.veteran_email_address
        first_name = submission.get_first_name
        date_submitted = submission.format_creation_time_for_mailers

        notify_service_bd = Settings.vanotify.services.benefits_disability
        notify_client = VaNotify::Service.new(notify_service_bd.api_key)
        template_id = notify_service_bd.template_id.form0781_upload_failure_notification_template_id

        notify_response = notify_client.send_email(
          email_address:,
          template_id:,
          personalisation: { first_name:, date_submitted: }
        )

        log_info = { form526_submission_id: submission.id, timestamp: Time.now.utc }

        log_mailer_dispatch(submission, log_info, notify_response)
      end

      def log_mailer_dispatch(submission, log_info, email_response = {})
        StatsD.increment("#{STATSD_METRIC_PREFIX}.success")

        Rails.logger.info('Form0781DocumentUploadFailureEmail notification dispatched', log_info)

        cl = caller_locations.first
        call_location = ZeroSilentFailures::Monitor::CallLocation.new(ZSF_DD_TAG_FUNCTION, cl.path, cl.lineno)
        zsf_monitor = ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE)

        zsf_monitor.log_silent_failure_avoided(
          log_info.merge(email_confirmation_id: email_response&.id),
          submission&.user_account_id,
          call_location:
        )
      end
    end
  end
end
