# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaim < ActiveRecord::Base
    attr_encrypted(:form_data_encrypted)
    attr_encrypted(:auth_headers_encrypted)

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    def form
      @form ||= ClaimsApi::Form526.new(data: JSON.parse(form_data_encrypted))
    end
  end
end
