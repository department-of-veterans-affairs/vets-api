# frozen_string_literal: true

class BPDS::Submission < Submission
  self.table_name = 'bpds_submissions'

  include SubmissionEncryption

  has_many :submission_attempts, class_name: 'BPDS::SubmissionAttempt', foreign_key: :bpds_submission_id,
                                 dependent: :destroy, inverse_of: :submission
  belongs_to :saved_claim, optional: true
end
