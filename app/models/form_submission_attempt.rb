# frozen_string_literal: true

class FormSubmissionAttempt < ApplicationRecord
  include AASM

  belongs_to :form_submission
  has_one :saved_claim, through: :form_submission
  has_one :in_progress_form, through: :form_submission
  has_one :user_account, through: :form_submission

  has_kms_key
  has_encrypted :error_message, :response, key: :kms_key, **lockbox_options
  # We only have the ignored_columns here because I haven't yet removed the error_message and
  # response columns from the db. (The correct column names are error_message_ciphertext and response_ciphertext)
  # If we get around to doing that, we shouldn't need the following line.
  self.ignored_columns += %w[error_message response]

  HOUR_TO_SEND_NOTIFICATIONS = 9

  aasm do
    after_all_transitions :log_status_change

    state :pending, initial: true
    state :failure, :success, :vbms

    event :fail do
      after do
        log_info = { form_submission_id:,
                     benefits_intake_uuid: form_submission&.benefits_intake_uuid,
                     form_type: form_submission&.form_type }
        Rails.logger.info('Preparing to send Form Submission Attempt error email', log_info)
        is_form526_form4142 = form_submission.form_type == CentralMail::SubmitForm4142Job::FORM4142_FORMSUBMISSION_TYPE
        if Flipper.enabled?(:simple_forms_email_notifications) && !is_form526_form4142
          enqueue_result_email(:error)
        elsif Flipper.enabled?(:form526_send_4142_failure_notification) && is_form526_form4142
          Rails.logger.info('Sending Form526:Form4142 failure email', log_info)
          jid = EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail.perform_async(Form526Submission.find_by(saved_claim_id:).id)
          Rails.logger.info('Sent Form526:Form4142 failure email', log_info.merge({ jid: }))
        end
      end

      transitions from: :pending, to: :failure
    end

    event :succeed do
      transitions from: :pending, to: :success
    end

    event :vbms do
      after do
        enqueue_result_email(:received) if Flipper.enabled?(:simple_forms_email_notifications)
      end

      transitions from: :pending, to: :vbms
      transitions from: :success, to: :vbms
    end

    event :remediate do
      transitions from: :failure, to: :vbms
    end
  end

  def log_status_change
    log_hash = {
      form_submission_id:,
      benefits_intake_uuid: form_submission&.benefits_intake_uuid,
      form_type: form_submission&.form_type,
      from_state: aasm.from_state,
      to_state: aasm.to_state,
      event: aasm.current_event
    }
    if failure?
      log_hash[:message] = 'Form Submission Attempt failed'
      Rails.logger.error(log_hash)
    elsif vbms?
      log_hash[:message] = 'Form Submission Attempt went to vbms'
      Rails.logger.info(log_hash)
    else
      log_hash[:message] = 'Form Submission Attempt State change'
      Rails.logger.info(log_hash)
    end
  end

  private

  def enqueue_result_email(notification_type)
    config = {
      form_data: JSON.parse(form_submission.form_data),
      form_number: form_submission.form_type,
      confirmation_number: form_submission.benefits_intake_uuid,
      date_submitted: created_at.strftime('%B %d, %Y'),
      lighthouse_updated_at: lighthouse_updated_at&.strftime('%B %d, %Y')
    }

    SimpleFormsApi::NotificationEmail.new(
      config,
      notification_type:,
      user_account:
    ).send(at: time_to_send)
  end

  def time_to_send
    now = Time.now.in_time_zone('Eastern Time (US & Canada)')
    if now.hour < HOUR_TO_SEND_NOTIFICATIONS
      now.change(hour: HOUR_TO_SEND_NOTIFICATIONS,
                 min: 0)
    else
      now.tomorrow.change(
        hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0
      )
    end
  end
end
