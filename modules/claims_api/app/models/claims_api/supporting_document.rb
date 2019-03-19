# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class SupportingDocument < ApplicationRecord
    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    belongs_to :auto_established_claim
  end
end
