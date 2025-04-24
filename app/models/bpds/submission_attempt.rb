# frozen_string_literal: true

require 'json_marshal/marshaller'

class BPDS::SubmissionAttempt < SubmissionAttempt
  serialize :metadata, coder: JsonMarshal::Marshaller
  serialize :error_message, coder: JsonMarshal::Marshaller
  serialize :response, coder: JsonMarshal::Marshaller

  self.table_name = 'bpds_submission_attempts'

  belongs_to :submission, class_name: 'BPDS::Submission', foreign_key: :bpds_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission
end
