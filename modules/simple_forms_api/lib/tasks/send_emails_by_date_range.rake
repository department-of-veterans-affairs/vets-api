# frozen_string_literal: true

# Invoke this as follows (tested on ZShell):
#   rails "simple_forms_api:send_emails_by_date_range[1 January 2025,2 January 2025]"
namespace :simple_forms_api do
  task :send_emails_by_date_range, %i[start_date end_date] => :environment do |_, args|
    start_date = Time.zone.parse(args[:start_date])
    end_date = Time.zone.parse(args[:end_date])
    date_range = (start_date..end_date)
    form_submission_attempts = FormSubmissionAttempt.where(updated_at: date_range).where.not(aasm_state: :pending)
    successful_uuids = []

    form_submission_attempts.map do |form_submission_attempt|
      confirmation_number = form_submission_attempt.benefits_intake_uuid
      Rails.logger.info "Attempting to enqueue email for: #{confirmation_number}"

      now = Time.now.in_time_zone('Eastern Time (US & Canada)')
      time_to_send = now.tomorrow.change(hour: 9, min: 0)

      form_submission = form_submission_attempt.form_submission
      form_number = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[form_submission.form_type]
      notification_type = if form_submission_attempt.failure?
                            :error
                          elsif form_submission_attempt.vbms?
                            :received
                          else
                            Rails.logger.error(
                              'Invalid notification_type for FormSubmissionAttempt with benefits_intake_uuid: ' \
                              "#{confirmation_number}"
                            )
                            raise
                          end
      config = {
        form_data: JSON.parse(form_submission.form_data),
        form_number:,
        confirmation_number:,
        date_submitted: form_submission_attempt.created_at.strftime('%B %d, %Y'),
        lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
      }

      SimpleFormsApi::Notification::Email.new(
        config,
        notification_type:,
        user_account: form_submission.user_account
      ).send(at: time_to_send)

      successful_uuids << [confirmation_number, notification_type]
      Rails.logger.info "Successfully enqueued email for: #{confirmation_number}"
    end

    Rails.logger.info 'Successful UUIDS & notification types:'
    Rails.logger.info successful_uuids
  rescue => e
    Rails.logger.error(e)
    raise e
  end
end
