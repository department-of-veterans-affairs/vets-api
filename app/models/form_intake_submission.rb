# frozen_string_literal: true

class FormIntakeSubmission < ApplicationRecord
  include AASM

  belongs_to :form_submission

  has_kms_key
  has_encrypted :request_payload, :response, :error_message, key: :kms_key, **lockbox_options

  # Validations
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }
  validates :benefits_intake_uuid, presence: true

  # Scopes for common query patterns
  scope :pending, -> { where(aasm_state: 'pending') }
  scope :submitted, -> { where(aasm_state: 'submitted') }
  scope :success, -> { where(aasm_state: 'success') }
  scope :failed, -> { where(aasm_state: 'failed') }
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
  scope :stale_pending, -> { pending.where('created_at < ?', 1.day.ago) }

  # AASM state machine configuration
  aasm do
    after_all_transitions :log_status_change

    state :pending, initial: true
    state :submitted
    state :success
    state :failed

    event :submit do
      after do
        update!(submitted_at: Time.current)
      end

      transitions from: :pending, to: :submitted
    end

    event :succeed do
      after do
        update!(completed_at: Time.current)
        log_success_metrics
      end

      transitions from: :submitted, to: :success
    end

    event :fail do
      after do
        update!(completed_at: Time.current)
        log_failure_metrics
      end

      transitions from: %i[pending submitted], to: :failed
    end
  end

  def increment_retry_count!
    with_lock do
      update!(
        retry_count: retry_count + 1,
        last_attempted_at: Time.current
      )
    end
  end

  # Helper method to get form type from associated form_submission
  def form_type
    form_submission&.form_type
  end

  private

  # Log state changes to Rails logger
  def log_status_change
    log_level = :info
    log_hash = status_change_hash

    case aasm.current_event
    when :fail!
      log_level = :error
      log_hash[:message] = 'Form Intake Submission failed'
    when :succeed!
      log_hash[:message] = 'Form Intake Submission succeeded'
    when :submit!
      log_hash[:message] = 'Form Intake Submission submitted to GCIO'
    else
      log_hash[:message] = 'Form Intake Submission state change'
    end

    Rails.logger.public_send(log_level, log_hash)
  end

  # Build hash of key data for logging
  def status_change_hash
    {
      form_intake_submission_id: id,
      benefits_intake_uuid:,
      form_submission_id:,
      form_type:,
      retry_count:,
      from_state: aasm.from_state,
      to_state: aasm.to_state,
      event: aasm.current_event
    }
  end

  # Log success metrics to StatsD
  def log_success_metrics
    StatsD.increment(
      'form_intake.submission.success',
      tags: [
        "form_type:#{form_type}",
        "retry_count:#{retry_count}"
      ]
    )
  end

  # Log failure metrics to StatsD
  def log_failure_metrics
    StatsD.increment(
      'form_intake.submission.failed',
      tags: [
        "form_type:#{form_type}",
        "retry_count:#{retry_count}"
      ]
    )
  end
end
