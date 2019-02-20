# frozen_string_literal: true

require_dependency 'claims_api/form_526'

module ClaimsApi
  class AutoEstablishedClaim < ActiveRecord::Base
    attr_encrypted(:form_data, key: Settings.db_encryption_key)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key)

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    alias token id
  end
end
