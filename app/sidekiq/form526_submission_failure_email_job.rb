# frozen_string_literal: true

require 'va_notify/service'

class Form526SubmissionFailureEmailJob
  include Sidekiq::Job

  attr_reader :submission_id

  STATSD_PREFIX = 'api.form_526.veteran_notifications.form526_submission_failure_email'
  # https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/274bea7fb835e51626259ac16b32c33ab0b2088a/platform/practices/zero-silent-failures/logging-silent-failures.md#capture-silent-failures-state
  DD_ZSF_TAGS = [
    'service:disability-application',
    'function:526_backup_submission_to_lighthouse'
  ].freeze
  FORM_DESCRIPTIONS = {
    'form4142' => 'VA Form 21-4142',
    'form0781' => 'VA Form 21-0781',
    'form0781a' => 'VA Form 21-0781a',
    'form8940' => 'VA Form 21-8940'
  }.freeze

  sidekiq_options retry: 14

  sidekiq_retries_exhausted do |msg, _ex|
    job_id = msg['jid']
    error_class = msg['error_class']
    error_message = msg['error_message']
    form526_submission_id = msg['args'].first
    timestamp = Time.now.utc

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

    StatsD.increment("#{STATSD_PREFIX}.exhausted")
    StatsD.increment('silent_failure', tags: DD_ZSF_TAGS)
  rescue => e
    Rails.logger.error(
      'Failure in Form526SubmissionFailureEmailJob#sidekiq_retries_exhausted',
      {
        job_id:,
        messaged_content: e.message,
        submission_id:,
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

    personalisation = {
      first_name: submission.get_first_name,
      date_submitted: submission.format_creation_time_for_mailers,
      forms_submitted: forms_submitted(submission.form),
      files_submitted: files_submitted(submission.form['form526_uploads'])
    }

    email_client.send_email(
      email_address: submission.veteran_email_address,
      template_id:,
      personalisation:
    )
  end

  def forms_submitted(form)
    [].tap do |forms|
      forms << FORM_DESCRIPTIONS['form4142'] if form['form4142'].present?
      forms << FORM_DESCRIPTIONS['form0781'] if form['form0781'].present?
      forms << FORM_DESCRIPTIONS['form0781a'] if form.dig('form0781', 'form0781a').present?
      forms << FORM_DESCRIPTIONS['form8940'] if form['form8940'].present?
    end
  end

  def files_submitted(uploads)
    return [] if uploads.nil?

    guids = uploads.map { |data| data&.dig('confirmationCode') }.compact
    files = SupportingEvidenceAttachment.where(guid: guids)
    files.map(&:obscured_filename)
  end

  def track_remedial_action(submission)
    Form526SubmissionRemediation.create!(
      form526_submission: submission,
      remediation_type: Form526SubmissionRemediation.remediation_types['email_notified'],
      lifecycle: ['Email failure notification sent']
    )
  end

  def log_success(submission)
    Rails.logger.info(
      'Form526SubmissionFailureEmail notification dispatched',
      {
        form526_submission_id: submission.id,
        timestamp: Time.now.utc
      }
    )

    StatsD.increment("#{STATSD_PREFIX}.success")
    StatsD.increment('silent_failure_avoided_no_confirmation', tags: DD_ZSF_TAGS)
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

    StatsD.increment("#{STATSD_PREFIX}.error")
  end
end
