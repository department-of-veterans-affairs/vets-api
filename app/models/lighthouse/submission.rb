# frozen_string_literal: true

require 'json_marshal/marshaller'

class Lighthouse::Submission < ApplicationRecord
  serialize :reference_data, coder: JsonMarshal::Marshaller

  self.table_name = 'lighthouse_submissions'

  validates :form_id, presence: true

  has_kms_key
  has_encrypted :reference_data, key: :kms_key, **lockbox_options

  has_many :lighthouse_submission_attempts, class_name: 'Lighthouse::SubmissionAttempt'
  belongs_to :saved_claim, optional: true
end
  