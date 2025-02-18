# frozen_string_literal: true

module Eps
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include Common::Client::Concerns::TokenAuthentication

    STATSD_KEY_PREFIX = 'api.eps'
    REDIS_TOKEN_KEY = REDIS_CONFIG[:eps_access_token][:namespace]
    REDIS_TOKEN_TTL = REDIS_CONFIG[:eps_access_token][:each_ttl]

    def config
      @config ||= Eps::Configuration.instance
    end

    private

    def patient_id
      @patient_id ||= user.icn
    end
  end
end
