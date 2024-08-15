# frozen_string_literal: true

class FormSubmission < ApplicationRecord
  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options

  has_many :form_submission_attempts, dependent: :destroy
  belongs_to :saved_claim, optional: true
  belongs_to :user_account, optional: true

  validates :form_type, presence: true

  def latest_pending_attempt
    form_submission_attempts.where(aasm_state: 'pending').order(created_at: :asc).last
  end
end
