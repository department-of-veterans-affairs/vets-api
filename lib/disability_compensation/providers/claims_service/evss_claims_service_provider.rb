# frozen_string_literal: true

require 'disability_compensation/providers/claims_service/claims_service_provider'
require 'disability_compensation/responses/claims_service_response'
require 'evss/claims_service'

class EvssClaimsServiceProvider
  include ClaimsServiceProvider
  def initialize(auth_headers)
    @service = EVSS::ClaimsService.new(auth_headers)
  end

  def all_claims(_client_id = nil, _rsa_key = nil)
    @service.all_claims.body
  end
end
