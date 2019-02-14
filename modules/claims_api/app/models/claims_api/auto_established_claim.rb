# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaim < ActiveRecord::Base
    attr_encrypted(:form_data_encrypted, key: Settings.db_encryption_key)
    attr_encrypted(:auth_headers_encrypted, key: Settings.db_encryption_key)

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    def form
      @form ||= ClaimsApi::Form526.new(data: JSON.parse(form_data_encrypted))
    end
  end
end
