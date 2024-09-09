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

  aasm do
    after_all_transitions :log_status_change

    state :pending, initial: true
    state :failure, :success, :vbms

    event :fail do
      transitions from: :pending, to: :failure
    end

    event :succeed do
      transitions from: :pending, to: :success
    end

    event :vbms do
      transitions from: :pending, to: :vbms
      transitions from: :success, to: :vbms
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
end
