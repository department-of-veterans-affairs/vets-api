# frozen_string_literal: true

class Lighthouse::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'lighthouse_submission_attempts'

  belongs_to :submission, class_name: 'Lighthouse::Submission', foreign_key: :lighthouse_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :lighthouse_submission
end
