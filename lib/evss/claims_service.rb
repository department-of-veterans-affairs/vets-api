# frozen_string_literal: true
require_dependency 'evss/base_service'

module EVSS
  class ClaimsService < BaseService
    def initialize(vaafi_headers = {})
      super()
      # TODO: Get base URI from env
      @base_url = 'http://csraciapp6.evss.srarad.com:7003/wss-claims-services-web-3.1/rest'
      @headers = vaafi_headers
    end

    def claims
      get 'vbaClaimStatusService/getOpenClaims'
    end

    def create_intent_to_file
      post 'claimServicesExternalService/listAllIntentToFile', '{}'
    end

    def submit_5103_waiver(claim_id)
      post 'vbaClaimStatusService/set5103Waiver', {
        claimId: claim_id,
        systemName: SYSTEM_NAME
      }.to_json
    end
  end
end
