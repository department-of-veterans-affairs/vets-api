# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  class ClaimsService < BaseService
    include SentryLogging

    API_VERSION = Settings.evss.versions.claims
    BASE_URL = "#{Settings.evss.url}/wss-claims-services-web-#{API_VERSION}/rest"
    BENCHMARK_KEY = 'evss_benchmark'

    def initialize(*args)
      super
      @benchmark_request = BenchmarkRequest.new('evss')
    end

    def all_claims
      benchmark_request { get 'vbaClaimStatusService/getClaims' }
    end

    def find_claim_by_id(claim_id)
      benchmark_request do
        post 'vbaClaimStatusService/getClaimDetailById', { id: claim_id }.to_json
      end
    end

    def request_decision(claim_id)
      benchmark_request do
        post 'vbaClaimStatusService/set5103Waiver', {
          claimId: claim_id,
          systemName: SYSTEM_NAME
        }.to_json
      end
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Claims', url: BASE_URL)
    end

    private

    def benchmark_request(&block)
      @benchmark_request.benchmark(&block)
    end
  end
end
