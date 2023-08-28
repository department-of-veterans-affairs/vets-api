# frozen_string_literal: true

require 'disability_compensation/providers/claims_service/claims_service_provider'
require 'disability_compensation/responses/claims_service_response'
require 'evss/claims_service'

class EvssClaimsServiceProvider
  include ClaimsServiceProvider
  def initialize(current_user = nil, auth_headers = nil)
    @service = EVSS::ClaimsService.new(current_user, auth_headers)
  end

  def all_claims(_client_id = nil, _rsa_key = nil)
    @service.all_claims.body
  end
end
