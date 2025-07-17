# frozen_string_literal: true

require 'json_marshal/marshaller'

# Concern to add encryption columns to Submission class
module SubmissionEncryption
  extend ActiveSupport::Concern

  included do
    serialize :reference_data, coder: JsonMarshal::Marshaller

    has_kms_key
    has_encrypted :reference_data, key: :kms_key, **lockbox_options
  end
end

# Representation of an abstract Submission to a service
class Submission < ApplicationRecord
  self.abstract_class = true

  validates :form_id, presence: true

  has_many :submission_attempts, dependent: :destroy

  def latest_attempt
    submission_attempts&.order(created_at: :desc)&.first
  end

  def update_reference_data(*args, **kwargs)
    self.reference_data ||= {}
    reference_data['data'] = args
    reference_data.merge kwargs
  end
end
