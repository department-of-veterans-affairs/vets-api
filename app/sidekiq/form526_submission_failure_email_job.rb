# frozen_string_literal: true

require 'va_notify/service'

class Form526SubmissionFailureEmailJob
  include Sidekiq::Job

  attr_accessor :submission

  STATSD_PREFIX = 'api.form_526.veteran_notifications.form526_submission_failure_email'
  # https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/274bea7fb835e51626259ac16b32c33ab0b2088a/platform/practices/zero-silent-failures/logging-silent-failures.md#capture-silent-failures-state
  ZSF_DD_TAG_FUNCTION = '526_backup_submission_to_lighthouse'
  VA_NOTIFY_CALLBACK_OPTIONS = {
    callback_metadata: {
      notification_type: 'error',
      form_number: Form526Submission::FORM_526,
      statsd_tags: { service: Form526Submission::ZSF_DD_TAG_SERVICE, function: ZSF_DD_TAG_FUNCTION }
    }
  }.freeze
  DD_ZSF_TAGS = [
    "service:#{Form526Submission::ZSF_DD_TAG_SERVICE}",
    "function:#{ZSF_DD_TAG_FUNCTION}"
  ].freeze
  FORM_DESCRIPTIONS = {
    'form4142' => 'VA Form 21-4142',
    'form0781' => 'VA Form 21-0781',
    'form0781a' => 'VA Form 21-0781a',
    'form0781v2' => 'VA Form 21-0781',
    'form8940' => 'VA Form 21-8940'
  }.freeze
  FORM_KEYS = {
    'form4142' => 'form4142',
    'form0781' => 'form0781.form0781',
    'form0781a' => 'form0781.form0781a',
    'form0781v2' => 'form0781.form0781v2',
    'form8940' => 'form8940'
  }.freeze

  # retry for  2d 1h 47m 12s
  # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
  sidekiq_options retry: 16

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

  def perform(submission_id, date_of_failure = Time.now.utc.to_s)
    @submission = Form526Submission.find(submission_id)
    @date_of_failure = Time.zone.parse(date_of_failure)
    send_email
    track_remedial_action
    log_success
  rescue => e
    log_failure(e)
    raise
  end

  private

  def send_email
    email_client = VaNotify::Service.new(Settings.vanotify.services.benefits_disability.api_key,
                                         VA_NOTIFY_CALLBACK_OPTIONS)
    template_id = Settings.vanotify.services.benefits_disability.template_id
                          .form526_submission_failure_notification_template_id

    email_client.send_email(
      email_address: submission.veteran_email_address,
      template_id:,
      personalisation:
    )
  end

  def list_forms_submitted
    FORM_KEYS.each_with_object([]) do |(key, path), forms|
      forms << FORM_DESCRIPTIONS[key] if form.dig(*path.split('.')).present?
    end
  end

  def list_files_submitted
    return [] if form['form526_uploads'].blank?

    guids = form['form526_uploads'].map { |data| data&.dig('confirmationCode') }.compact
    files = SupportingEvidenceAttachment.where(guid: guids)
    files.map(&:obscured_filename)
  end

  def personalisation
    {
      first_name: submission.get_first_name,
      date_submitted: submission.format_creation_time_for_mailers,
      forms_submitted: list_forms_submitted.presence || 'None',
      files_submitted: list_files_submitted.presence || 'None',
      date_of_failure: parsed_date_of_failure
    }
  end

  def parsed_date_of_failure
    @date_of_failure.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end

  def track_remedial_action
    Form526SubmissionRemediation.create!(
      form526_submission: submission,
      remediation_type: Form526SubmissionRemediation.remediation_types['email_notified'],
      lifecycle: ['Email failure notification sent']
    )
  end

  def log_success
    Rails.logger.info(
      'Form526SubmissionFailureEmailJob notification dispatched',
      {
        form526_submission_id: submission.id,
        timestamp: Time.now.utc
      }
    )

    StatsD.increment("#{STATSD_PREFIX}.success")
  end

  def log_failure(error)
    Rails.logger.error(
      'Form526SubmissionFailureEmailJob notification failed',
      {
        form526_submission_id: submission&.id,
        error_message: error.try(:message),
        timestamp: Time.now.utc
      }
    )

    StatsD.increment("#{STATSD_PREFIX}.error")
  end

  def form
    @form ||= submission.form
  end
end
