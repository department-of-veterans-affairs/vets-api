# frozen_string_literal: true

class ClaimsEvidenceApi::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'claims_evidence_api_submission_attempts'

  include SubmissionAttemptEncryption

  belongs_to :submission, class_name: 'ClaimsEvidenceApi::Submission', foreign_key: :claims_evidence_api_submissions_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission
end
