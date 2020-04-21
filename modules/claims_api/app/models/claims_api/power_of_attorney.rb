# frozen_string_literal: true

require_dependency 'claims_api/concerns/file_data'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    include FileData
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:source_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    PENDING = 'pending'
    UPDATED = 'updated'
    ERRORED = 'errored'

    before_validation :set_md5
    validates :md5, uniqueness: true

    def date_request_accepted
      created_at&.to_date.to_s
    end

    def representative
      form_data.merge(participant_id: nil)
    end

    def veteran
      { participant_id: nil }
    end

    def previous_poa
      current_poa
    end

    def set_md5
      headers = auth_headers.except('va_eauth_authenticationauthority',
                                    'va_eauth_service_transaction_id',
                                    'va_eauth_issueinstant',
                                    'Authorization')
      self.header_md5 = Digest::MD5.hexdigest headers.to_json
      self.md5 = Digest::MD5.hexdigest form_data.merge(headers).to_json
    end

    def uploader
      @uploader ||= ClaimsApi::PowerOfAttorneyUploader.new(id)
    end

    def external_key
      source_data.present? ? source_data['email'] : Settings.bgs.external_key
    end

    def external_uid
      source_data.present? ? source_data['icn'] : Settings.bgs.external_uid
    end

    def self.pending?(id)
      query = where(id: id)
      query.exists? ? query.first : false
    end
  end
end
