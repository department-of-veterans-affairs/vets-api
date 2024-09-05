# frozen_string_literal: true

require 'json_marshal/marshaller'

class ClaimsApi::EvidenceWaiverSubmission < ApplicationRecord
  validates :cid, presence: true
  serialize :auth_headers, coder: JsonMarshal::Marshaller

  has_kms_key
  has_encrypted :auth_headers, key: :kms_key, **lockbox_options

  PENDING = 'pending'
  UPLOADED = 'uploaded'
  UPDATED = 'updated'
  ERRORED = 'errored'

  ALL_STATUSES = [PENDING, UPLOADED, UPDATED, ERRORED].freeze
end
