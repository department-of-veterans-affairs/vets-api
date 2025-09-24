# frozen_string_literal: true

# Represents an attempt to submit a BPDS (Benefits Processing Data Service) submission.
#
# This model inherits from SubmissionAttempt and is mapped to the 'bpds_submission_attempts' table.
# It includes encryption functionality via SubmissionAttemptEncryption.
#
# Associations:
# - Belongs to a BPDS::Submission, referenced by the foreign key :bpds_submission_id.
# - Has one SavedClaim through the associated submission.
class BPDS::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'bpds_submission_attempts'

  include SubmissionAttemptEncryption

  belongs_to :submission, class_name: 'BPDS::Submission', foreign_key: :bpds_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission
end
