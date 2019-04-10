# frozen_string_literal: true

require_dependency 'claims_api/form_526'
require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class AutoEstablishedClaim < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    has_many :supporting_documents, dependent: :destroy

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    before_validation :set_md5
    validates :md5, uniqueness: true

    alias token id

    def form
      @form ||= ClaimsApi::Form526.new(form_data.deep_symbolize_keys)
    end

    def self.pending?(id)
      query = where(id: id)
      query.exists? && query.first.evss_id.nil? ? query.first : false
    end

    def self.evss_id_by_token(token)
      find_by(id: token)&.evss_id
    end

    def set_md5
      headers = auth_headers.except('va_eauth_issueinstant')
      self.md5 = Digest::MD5.hexdigest form_data.merge(headers).to_json
    end
  end
end
