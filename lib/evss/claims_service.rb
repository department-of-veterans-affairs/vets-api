# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  class ClaimsService < BaseService
    include SentryLogging

    API_VERSION = Settings.evss.versions.claims
    BASE_URL = "#{Settings.evss.url}/wss-claims-services-web-#{API_VERSION}/rest"
    BENCHMARK_KEY = 'evss_benchmark'

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

    def log_benchmark(average, count)
      log_message_to_sentry(
        'Average EVSS request in seconds',
        :info,
        { average: average, count: count },
        backend_service: :evss
      )
    end

    def benchmark_request
      start = Time.current
      return_val = yield
      diff = Time.current - start
      redis = Redis.current
      count_key = "#{BENCHMARK_KEY}.count"
      count = redis.get(count_key)&.to_i
      average = redis.get(BENCHMARK_KEY)

      if count.nil? || average.nil?
        count = 1
        average = diff
      else
        average = BigDecimal.new(average)
        total = average * count + diff
        count += 1
        average = total / count
      end

      redis.set(BENCHMARK_KEY, average)
      redis.set(count_key, count)

      log_benchmark(average, count)

      return_val
    end
  end
end
