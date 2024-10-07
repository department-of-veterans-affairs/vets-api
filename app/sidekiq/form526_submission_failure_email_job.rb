# frozen_string_literal: true

require 'va_notify/service'

# [wipn8923] new job
class Form526SubmissionFailureEmailJob
  include Sidekiq::Job

  attr_reader :submission_id

  STATSD_METRIC_PREFIX = 'api.form_526.veteran_notifications.form526_submission_failure_email'

  sidekiq_options retry: 14

  sidekiq_retries_exhausted do |msg, _ex|
    job_id = msg['jid']
    error_class = msg['error_class']
    error_message = msg['error_message']
    form526_submission_id = msg['args'].first

    timestamp = Time.now.utc

    new_error = {
      "#{timestamp.to_i}": {
        caller_method: __method__.to_s,
        timestamp:,
        form526_submission_id:
      }
    }

    Rails.logger.warn(
      'Form526SubmissionFailureEmailJob retries exhausted',
      {
        job_id:,
        timestamp:,
        form526_submission_id:,
        error_class:,
        error_message:
      }
    )

    StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted")
  rescue => e
    Rails.logger.error(
      'Failure in Form526SubmissionFailureEmailJob#sidekiq_retries_exhausted',
      {
        job_id:,
        messaged_content: e.message,
        submission_id: submission_id,
        pre_exhaustion_failure: {
          error_class:,
          error_message:
        }
      }
    )
    raise e
  end

  def perform(submission_id)
    submission = Form526Submission.find(submission_id)
    send_email(submission)
    track_remedial_action(submission)
    log_success(submission)
  rescue => e
    log_failure(e, submission)
    raise
  end

  private

  def send_email(submission)
    email_client = VaNotify::Service.new(Settings.vanotify.services.benefits_disability.api_key)
    template_id = Settings.vanotify.services.benefits_disability.template_id
      .form526_submission_failure_notification_template_id

    email_client.send_email(
      email_address: submission.veteran_email_address,
      template_id:,
      personalisation: {
        first_name: submission.get_first_name,
        date_submitted: submission.format_creation_time_for_mailers
      }
    )
  end

  def track_remedial_action(submission)
    Form526SubmissionRemediation.create!(form526_submission: submission,
                                         remediation_type: Form526SubmissionRemediation::remediation_types['email_notified'],
                                         lifecycle: ['Email failure notification sent'])
  end

  def log_success(submission)
    Rails.logger.info(
      'Form526SubmissionFailureEmail notification dispatched',
      {
        form526_submission_id: submission.id,
        timestamp: Time.now.utc
      }
    )

    StatsD.increment("#{STATSD_METRIC_PREFIX}.success")
  end

  def log_failure(error, submission)
    Rails.logger.error(
      'Form526SubmissionFailureEmail notification failed',
      {
        form526_submission_id: submission.id,
        error_message: error.try(:message),
        timestamp: Time.now.utc
      }
    )

    StatsD.increment("#{STATSD_METRIC_PREFIX}.error")
  end
end
