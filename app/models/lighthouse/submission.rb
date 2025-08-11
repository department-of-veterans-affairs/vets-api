# frozen_string_literal: true

class Lighthouse::Submission < Submission
  self.table_name = 'lighthouse_submissions'

  include SubmissionEncryption

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
