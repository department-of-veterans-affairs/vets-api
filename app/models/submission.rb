# frozen_string_literal: true

require 'json_marshal/marshaller'

module SubmissionEncryption
  extend ActiveSupport::Concern

  included do
    serialize :reference_data, coder: JsonMarshal::Marshaller

    has_kms_key
    has_encrypted :reference_data, key: :kms_key, **lockbox_options

    def reference
      JSON.parse(reference_data || {}.to_json, symbolize_names: true)
    end

    def reference=(data)
      self.reference_data = JSON.generate(data)
    end
  end
end

class Submission < ApplicationRecord
  self.abstract_class = true

  validates :form_id, presence: true
end
