# frozen_string_literal: true

require 'json_marshal/marshaller'

module SubmissionEncryption
  extend ActiveSupport::Concern

  included do
    serialize :reference_data, coder: JsonMarshal::Marshaller

    has_kms_key
    has_encrypted :reference_data, key: :kms_key, **lockbox_options
  end
end

class Submission < ApplicationRecord
  self.abstract_class = true

  validates :form_id, presence: true

  has_many :submission_attempts, dependent: :destroy

  def latest_attempt
    submission_attempts&.order(created_at: :asc).last
  end
end
