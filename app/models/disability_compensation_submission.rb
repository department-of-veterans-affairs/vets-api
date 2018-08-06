# frozen_string_literal: true

class DisabilityCompensationSubmission < ActiveRecord::Base
  enum status: {
    submitted: 'submitted',
    received: 'received',
    retrying: 'retrying',
    non_retryable_error: 'non_retryable_error',
    exhausted: 'exhausted'
  }

  validates :user_uuid, presence: true, uniqueness: { scope: :form_type }
  validates :form_type, presence: true, uniqueness: { scope: :user_uuid }
  validates :claim_id, presence: true, uniqueness: true
end
