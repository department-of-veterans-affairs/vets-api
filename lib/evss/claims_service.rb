# frozen_string_literal: true

require 'evss/base_service'

module EVSS
  class ClaimsService < BaseService
    API_VERSION = Settings.evss.versions.claims
    BASE_URL = "#{Settings.evss.url}/wss-claims-services-web-#{API_VERSION}/rest"
    DEFAULT_TIMEOUT = 120 # in seconds

    def initialize(*args)
      super
    end

    def all_claims
      get 'vbaClaimStatusService/getClaims'
    end

    def find_claim_by_id(claim_id)
      post 'vbaClaimStatusService/getClaimDetailById', { id: claim_id }.to_json
    end

    def request_decision(claim_id)
      post 'vbaClaimStatusService/set5103Waiver', {
        claimId: claim_id,
        systemName: SYSTEM_NAME
      }.to_json
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Claims', url: BASE_URL)
    end
  end
end
