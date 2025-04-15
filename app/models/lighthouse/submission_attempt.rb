# frozen_string_literal: true

require 'json_marshal/marshaller'

class Lighthouse::SubmissionAttempt < ApplicationRecord
  serialize :metadata, coder: JsonMarshal::Marshaller
  serialize :error_message, coder: JsonMarshal::Marshaller
  serialize :response, coder: JsonMarshal::Marshaller

  self.table_name = 'lighthouse_submission_attempts'

  validates :lighthouse_submission_id, presence: true

  has_kms_key
  has_encrypted :metadata, :error_message, :response, key: :kms_key, **lockbox_options
  
  belongs_to :lighthouse_submission, class_name: 'Lighthouse::Submission'
  has_one :saved_claim, through: :lighthouse_submission
end
    