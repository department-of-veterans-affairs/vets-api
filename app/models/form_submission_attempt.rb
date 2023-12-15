# frozen_string_literal: true

class FormSubmissionAttempt < ApplicationRecord
  include AASM

  belongs_to :form_submission
  has_one :saved_claim, through: :form_submission
  has_one :in_progress_form, through: :form_submission
  has_one :user_account, through: :form_submission

  has_kms_key
  has_encrypted :error_message, :response, key: :kms_key, **lockbox_options

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
    Rails.logger.info(
      {
        name: 'Form Submissions Attempt State change',
        form_submission_id:,
        from_state: aasm.from_state,
        to_state: aasm.to_state,
        event: aasm.current_event
      }
    )
  end
end
