# frozen_string_literal: true

class MultiPartyFormSubmission < ApplicationRecord
  include AASM

  # Associations
  belongs_to :primary_in_progress_form,
             class_name: 'InProgressForm'
  belongs_to :secondary_in_progress_form,
             class_name: 'InProgressForm',
             optional: true
  belongs_to :saved_claim, optional: true

  # Validations
  validates :form_type, presence: true
  validates :primary_user_uuid, presence: true
  validates :secondary_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # AASM state machine configuration
  aasm column: :status do
    state :primary_in_progress, initial: true
    state :awaiting_secondary_start
    state :secondary_in_progress
    state :awaiting_primary_review
    state :submitted

    event :primary_complete do
      transitions from: :primary_in_progress,
                  to: :awaiting_secondary_start,
                  guard: -> { secondary_email.present? },
                  after: :notify_secondary_party
    end

    event :secondary_start do
      transitions from: :awaiting_secondary_start,
                  to: :secondary_in_progress
    end

    event :secondary_complete do
      transitions from: :secondary_in_progress,
                  to: :awaiting_primary_review,
                  after: :notify_primary_of_completion
    end

    event :primary_submit do
      transitions from: :awaiting_primary_review,
                  to: :submitted,
                  after: :process_final_submission
    end
  end

  # Scopes
  scope :pending_for_secondary,
      ->(email) { where(secondary_email: email, status: %w[awaiting_secondary_start secondary_in_progress]) }
  scope :for_primary_user, ->(uuid) { where(primary_user_uuid: uuid) }
  scope :for_secondary_user, ->(uuid) { where(secondary_user_uuid: uuid) }

  # Methods
  def primary_form_id
    "#{form_type}-PRIMARY"
  end

  def secondary_form_id
    "#{form_type}-SECONDARY"
  end

  def generate_secondary_access_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(
      secondary_access_token_digest: Digest::SHA256.hexdigest(token),
      secondary_access_token_expires_at: 30.days.from_now
    )
    token
  end

  def verify_secondary_token(token)
    return false if secondary_access_token_expires_at.nil?
    return false if secondary_access_token_expires_at < Time.current
    Digest::SHA256.hexdigest(token) == secondary_access_token_digest
  end

  private

  def notify_secondary_party
    MultiPartyForms::NotifySecondaryPartyJob.perform_async(id)
    update!(secondary_notified_at: Time.current)
  end

  def notify_primary_of_completion
    MultiPartyForms::NotifyPrimaryPartyJob.perform_async(id, 'secondary_completed')
  end

  def process_final_submission
    MultiPartyForms::SubmitFormJob.perform_async(id)
    update!(submitted_at: Time.current)
  end
end
