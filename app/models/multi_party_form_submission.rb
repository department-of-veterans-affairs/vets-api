# frozen_string_literal: true

class MultiPartyFormSubmission < ApplicationRecord
  include AASM

  # Associations
  belongs_to :primary_in_progress_form, class_name: 'InProgressForm', optional: true
  belongs_to :secondary_in_progress_form, class_name: 'InProgressForm', optional: true
  belongs_to :saved_claim, optional: true

  # Validations
  validates :form_type, presence: true
  validates :primary_user_uuid, presence: true
  validates :status, presence: true

  # State machine
  aasm column: :status do
    state :primary_in_progress, initial: true
    state :awaiting_secondary_completion
    state :awaiting_primary_review
    state :submitted

    # Primary Party completes their sections (I-V) and provides secondary email
    event :primary_complete do
      transitions from: :primary_in_progress, to: :awaiting_secondary_completion

      after do
        notify_secondary_party
      end
    end

    # Secondary Party completes their sections
    event :secondary_complete do
      transitions from: :awaiting_secondary_completion, to: :awaiting_primary_review
    end

    # Primary Party reviews and submits final form
    event :primary_submit do
      transitions from: :awaiting_primary_review, to: :submitted

      after do
        process_final_submission
      end
    end
  end

  private

  def notify_secondary_party
    # Enqueue job to send email notification to secondary party
    # NotifySecondaryPartyJob.perform_async(id)
    # For now, just update the timestamp
    update(secondary_notified_at: Time.current)
  end

  def process_final_submission
    # Enqueue job to process final submission
    # SubmitFormJob.perform_async(id)
    # For now, just update the timestamp
    update(submitted_at: Time.current)
  end
end
