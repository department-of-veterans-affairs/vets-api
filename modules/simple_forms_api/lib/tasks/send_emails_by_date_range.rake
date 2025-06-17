# frozen_string_literal: true

# Invoke this as follows (tested on ZShell):
#   rails "simple_forms_api:send_emails_by_date_range[1 January 2025,2 January 2025]"
namespace :simple_forms_api do
  task :send_emails_by_date_range, %i[start_date end_date] => :environment do |_, args|
    start_date = Time.zone.parse(args[:start_date])
    end_date = Time.zone.parse(args[:end_date])
    form_submission_attempts = fetch_form_submission_attempts(start_date, end_date)
    Rails.logger.info "Total FormSubmissionAttempts found: #{form_submission_attempts.count}"
    successful_uuids, failure_notifications_sent = process_form_submission_attempts(form_submission_attempts)
    log_results(successful_uuids, failure_notifications_sent)
  end

  def fetch_form_submission_attempts(start_date, end_date)
    date_range = (start_date..end_date)
    FormSubmissionAttempt
      .joins(:form_submission)
      .where(updated_at: date_range)
      .where.not(aasm_state: :pending)
      .where(form_submissions: { form_type: SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP.keys })
  end

  def process_form_submission_attempts(form_submission_attempts)
    failure_notifications_sent = []
    errors = []

    confirmation_numbers = form_submission_attempts.map do |form_submission_attempt|
      confirmation_number = form_submission_attempt.benefits_intake_uuid
      send_email(form_submission_attempt, failure_notifications_sent, confirmation_number)
      Rails.logger.info "Successfully enqueued email for: #{confirmation_number}"
      confirmation_number
    rescue => e
      errors << { message: e.message, backtrace: e.backtrace, confirmation_number: }
    end

    log_errors(errors)
    [confirmation_numbers, failure_notifications_sent]
  end

  def send_email(form_submission_attempt, error_notifications_sent, confirmation_number)
    Rails.logger.info "Attempting to enqueue email for: #{confirmation_number}"
    now = Time.now.in_time_zone('Eastern Time (US & Canada)')
    time_to_send = now.tomorrow.change(hour: 9, min: 0)
    form_submission = form_submission_attempt.form_submission
    notification_type = get_notification_type(form_submission_attempt)
    error_notifications_sent << confirmation_number if notification_type == :error

    SimpleFormsApi::Notification::Email.new(
      config(form_submission_attempt, form_submission, confirmation_number),
      notification_type:,
      user_account: form_submission.user_account
    ).send(at: time_to_send)
  end

  def log_results(successful_uuids, failure_notifications_sent)
    log_successful_attempts(successful_uuids)
    Rails.logger.info('Total successful', successful_count: successful_uuids.count)
    Rails.logger.info('Failure notifications successfully sent:',
                      failure_notifications_sent_count: failure_notifications_sent.count)
  end

  def log_successful_attempts(successful_uuids)
    Rails.logger.info 'Successful UUIDS & notification types:'
    Rails.logger.info successful_uuids
  end

  def log_errors(errors)
    Rails.logger.error 'Errors:'
    errors.each do |error|
      Rails.logger.error('SendEmailsByDateRange error.', confirmation_number: error[:confirmation_number],
                                                         message: error[:message], backtrace: error[:backtrace])
    end
  end

  def get_notification_type(form_submission_attempt)
    if form_submission_attempt.failure?
      :error
    elsif form_submission_attempt.vbms?
      :received
    else
      Rails.logger.error(
        "Invalid notification_type for FormSubmissionAttempt with benefits_intake_uuid: #{confirmation_number}"
      )
      raise
    end
  end

  def config(form_submission_attempt, form_submission, confirmation_number)
    form_number = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[form_submission.form_type]
    {
      form_data: JSON.parse(form_submission.form_data),
      form_number:,
      confirmation_number:,
      date_submitted: form_submission_attempt.created_at.strftime('%B %d, %Y'),
      lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
    }
  end
end
