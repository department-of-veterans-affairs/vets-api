# frozen_string_literal: true

require 'json_marshal/marshaller'
class BPDS::Submission < Submission
  serialize :reference_data, coder: JsonMarshal::Marshaller

  self.table_name = 'bpds_submissions'

  has_kms_key
  has_encrypted :reference_data, key: :kms_key, **lockbox_options

  has_many :submission_attempts, class_name: 'BPDS::SubmissionAttempt', foreign_key: :bpds_submission_id
  belongs_to :saved_claim, optional: true
end
