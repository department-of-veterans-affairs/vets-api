# frozen_string_literal: true

class Lighthouse::Submission < Submission
  self.table_name = 'lighthouse_submissions'

  has_many :submission_attempts, class_name: 'Lighthouse::SubmissionAttempt', dependent: :destroy,
                                 foreign_key: :lighthouse_submission_id, inverse_of: :submission
  belongs_to :saved_claim, optional: true
end
