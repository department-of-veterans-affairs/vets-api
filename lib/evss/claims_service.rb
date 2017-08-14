# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  class ClaimsService < BaseService
    API_VERSION = Settings.evss.versions.claims
    BASE_URL = "#{Settings.evss.url}/wss-claims-services-web-#{API_VERSION}/rest"
    BENCHMARK_KEY = 'evss_benchmark'

    def send_request
      start = Time.current
      yield
      diff = Time.current - start
      redis = Redis.current
      count_key = "#{BENCHMARK_KEY}.count"
      count = redis.get(count_key)&.to_i
      average = redis.get(BENCHMARK_KEY)

      new_average =
        if count.nil? || average.nil?
          redis.set(count_key, 1)
          diff
        else
          average = BigDecimal.new(average)
          total = average * count + diff
          count += 1
          redis.set(count_key, count)
          total / count
        end

      redis.set(BENCHMARK_KEY, new_average)
      # TODO: log to sentry
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
