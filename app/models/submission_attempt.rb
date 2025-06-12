# frozen_string_literal: true

require 'json_marshal/marshaller'

module SubmissionAttemptEncryption
  extend ActiveSupport::Concern

  included do
    serialize :metadata, coder: JsonMarshal::Marshaller
    serialize :error_message, coder: JsonMarshal::Marshaller
    serialize :response, coder: JsonMarshal::Marshaller

    has_kms_key
    has_encrypted :metadata, key: :kms_key, **lockbox_options
    has_encrypted :error_message, key: :kms_key, **lockbox_options
    has_encrypted :response, key: :kms_key, **lockbox_options
  end
end

class SubmissionAttempt < ApplicationRecord
  self.abstract_class = true

  validates :submission, presence: true

  belongs_to :submission, inverse_of: :submission_attempts

  after_create :update_submission_status
  before_update :update_submission_status

  private

  def update_submission_status
    submission.update(latest_status: status) if status_changed? || id_previously_changed?
  end
end
