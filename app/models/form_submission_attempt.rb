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
        if should_send_simple_forms_email
          Rails.logger.info({
                              message: 'Preparing to send Form Submission Attempt error email',
                              form_submission_id:,
                              benefits_intake_uuid: form_submission.benefits_intake_uuid,
                              form_type: form_submission.form_type
                            })
          simple_forms_enqueue_result_email(:error)
        end
      end

      transitions from: :pending, to: :failure
    end

    event :succeed do
      transitions from: :pending, to: :success
    end

    event :vbms do
      after do
        simple_forms_enqueue_result_email(:received) if should_send_simple_forms_email
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
    if aasm.current_event == 'fail!'
      log_hash[:message] = 'Form Submission Attempt failed'
      Rails.logger.error(log_hash)
    elsif aasm.current_event == 'vbms!'
      log_hash[:message] = 'Form Submission Attempt went to vbms'
      Rails.logger.info(log_hash)
    else
      log_hash[:message] = 'Form Submission Attempt State change'
      Rails.logger.info(log_hash)
    end
  end

  private

  def should_send_simple_forms_email
    simple_forms_form_number && Flipper.enabled?(:simple_forms_email_notifications)
  end

  def simple_forms_enqueue_result_email(notification_type)
    raw_form_data = form_submission.form_data || '{}'
    form_data = JSON.parse(raw_form_data)
    config = {
      form_data:,
      form_number: simple_forms_form_number,
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

  def simple_forms_form_number
    @simple_forms_form_number ||=
      if SimpleFormsApi::NotificationEmail::TEMPLATE_IDS.keys.include? form_submission.form_type
        form_submission.form_type
      else
        SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[form_submission.form_type]
      end
  end
end
