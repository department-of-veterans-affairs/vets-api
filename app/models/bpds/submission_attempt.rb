# frozen_string_literal: true

class BPDS::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'bpds_submission_attempts'

  belongs_to :submission, class_name: 'BPDS::Submission', foreign_key: :bpds_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission
end
