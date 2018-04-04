# frozen_string_literal: true

require 'evss/base_service'
require 'sentry/rescue_evss_errors.rb'

module EVSS
  class ClaimsService < BaseService
    include Sentry::RescueEVSSErrors

    API_VERSION = Settings.evss.versions.claims
    BASE_URL = "#{Settings.evss.url}/wss-claims-services-web-#{API_VERSION}/rest"
    DEFAULT_TIMEOUT = 120 # in seconds

    def initialize(*args)
      super
      @use_mock = Settings.evss.mock_claims || false
    end

    def all_claims
      rescue_evss_errors do
        get 'vbaClaimStatusService/getClaims'
      end
    end

    def find_claim_by_id(claim_id)
      rescue_evss_errors do
        post 'vbaClaimStatusService/getClaimDetailById', { id: claim_id }.to_json
      end
    end

    def request_decision(claim_id)
      rescue_evss_errors do
        post 'vbaClaimStatusService/set5103Waiver', {
          claimId: claim_id,
          systemName: SYSTEM_NAME
        }.to_json
      end
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Claims', url: BASE_URL)
    end
  end
end
