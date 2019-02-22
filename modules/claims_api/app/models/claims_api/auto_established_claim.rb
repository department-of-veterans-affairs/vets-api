# frozen_string_literal: true

require_dependency 'claims_api/form_526'
require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class AutoEstablishedClaim < ActiveRecord::Base
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    alias token id

    def form
      @form ||= ClaimsApi::Form526.new(form_data.deep_symbolize_keys)
    end
  end
end
