# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'
require_dependency 'claims_api/concerns/file_data_validation'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    include FileDataValidation
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    PENDING = 'pending'
    UPDATED = 'updated'
    ERRORED = 'errored'

    before_validation :set_md5
    validates :md5, uniqueness: true

    def date_request_accepted
      created_at&.to_date.to_s
    end

    def representative
      form_data.merge(current_poa: current_poa, participant_id: nil)
    end

    def veteran
      { participant_id: nil }
    end

    def set_md5
      headers = auth_headers.except('va_eauth_issueinstant', 'Authorization')
      self.md5 = Digest::MD5.hexdigest form_data.merge(headers).to_json
    end

    def uploader
      @uploader ||= ClaimsApi::PowerOfAttorneyUploader.new(id)
    end

    def self.pending?(id)
      query = where(id: id)
      query.exists? ? query.first : false
    end
  end
end
