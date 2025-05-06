# frozen_string_literal: true

require 'json_marshal/marshaller'

class DecisionReviewNotificationAuditLog < ApplicationRecord
  serialize :payload, coder: JsonMarshal::Marshaller

  has_kms_key
  has_encrypted :payload, key: :kms_key, **lockbox_options

  validates(:payload, presence: true)

  before_save :serialize_payload

  private

  def serialize_payload
    self.payload = payload.to_json unless payload.is_a?(String)
  end
end
