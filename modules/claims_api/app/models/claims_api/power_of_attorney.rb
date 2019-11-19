# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

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

    def file_name
      file_data['filename']
    end

    def document_type
      file_data['doc_type']
    end

    def set_file_data!(file_data, doc_type)
      uploader.store!(file_data)
      self.file_data = { filename: uploader.filename,
                         doc_type: doc_type }
    end

    def uploader
      @uploader ||= ClaimsApi::PowerOfAttorneyUploader.new(id)
    end

    def self.pending?(id)
      where(id: id).any?
    end
  end
end
