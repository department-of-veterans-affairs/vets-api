# frozen_string_literal: true

require 'json_marshal/marshaller'

class Lighthouse::Submission < Submission
  serialize :reference_data, coder: JsonMarshal::Marshaller

  self.table_name = 'lighthouse_submissions'

  has_kms_key
  has_encrypted :reference_data, key: :kms_key, **lockbox_options

  validates :form_id, presence: true

  has_many :submission_attempts, class_name: 'Lighthouse::SubmissionAttempt', dependent: :destroy,
                                 foreign_key: :lighthouse_submission_id, inverse_of: :submission
  belongs_to :saved_claim, optional: true

  def latest_attempt
    submission_attempts.order(created_at: :asc).last
  end

  def latest_pending_attempt
    submission_attempts.where(status: 'pending').order(created_at: :asc).last
  end

  def non_failure_attempt
    submission_attempts.where(status: %w[pending submitted]).first
  end
end
