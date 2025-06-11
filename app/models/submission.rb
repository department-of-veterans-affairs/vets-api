# frozen_string_literal: true

require 'json_marshal/marshaller'

class Submission < ApplicationRecord
  self.abstract_class = true

  serialize :reference_data, coder: JsonMarshal::Marshaller

  has_kms_key
  has_encrypted :reference_data, key: :kms_key, **lockbox_options

  validates :form_id, presence: true
end
