# frozen_string_literal: true

require 'json_marshal/marshaller'

class ClaimsApi::EvidenceWaiverSubmission < ApplicationRecord
  validates :cid, :auth_headers_ciphertext, presence: true
  serialize :auth_headers, JsonMarshal::Marshaller

  has_kms_key
  has_encrypted :auth_headers, key: :kms_key, **lockbox_options
end
