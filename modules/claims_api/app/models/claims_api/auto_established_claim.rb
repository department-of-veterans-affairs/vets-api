# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaim < ActiveRecord::Base
    attr_encrypted(:form_data, key: Settings.db_encryption_key)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key)

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    alias :token, :id

    def form
      @form ||= ClaimsApi::Form526.new(data: JSON.parse(form_data))
    end
  end
end
