# frozen_string_literal: true

require_dependency 'claims_api/form_2122'
require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    before_validation :set_md5
    validates :md5, uniqueness: true

    def set_md5
      headers = auth_headers.except('va_eauth_issueinstant', 'Authorization')
      self.md5 = Digest::MD5.hexdigest form_data.merge(headers).to_json
    end
  end
end
