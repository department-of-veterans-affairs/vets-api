# frozen_string_literal: true

require 'json_marshal/marshaller'

class Lighthouse::SubmissionAttempt < SubmissionAttempt
  serialize :metadata, coder: JsonMarshal::Marshaller
  serialize :error_message, coder: JsonMarshal::Marshaller
  serialize :response, coder: JsonMarshal::Marshaller

  self.table_name = 'lighthouse_submission_attempts'

  belongs_to :submission, class_name: 'Lighthouse::Submission', foreign_key: :lighthouse_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :lighthouse_submission
end
