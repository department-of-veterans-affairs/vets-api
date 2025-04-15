# frozen_string_literal: true

require 'json_marshal/marshaller'

class Bpds::SubmissionAttempt < ApplicationRecord
  serialize :metadata, coder: JsonMarshal::Marshaller
  serialize :error_message, coder: JsonMarshal::Marshaller
  serialize :response, coder: JsonMarshal::Marshaller

  self.table_name = 'bpds_submission_attempts'

  validates :bpds_submission_id, presence: true

  has_kms_key
  has_encrypted :metadata, :error_message, :response, key: :kms_key, **lockbox_options
  
  belongs_to :bpds_submission, class_name: 'Bpds::Submission'
  has_one :saved_claim, through: :bpds_submission

  after_create :update_submission_status
  
  private

  def update_submission_status
    bpds_submission.update(latest_status: status)
  end
end
  