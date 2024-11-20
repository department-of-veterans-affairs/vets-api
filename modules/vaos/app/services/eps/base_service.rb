# frozen_string_literal: true

module Eps
  class BaseService < VAOS::SessionService
    STATSD_KEY_PREFIX = 'api.eps'

    def headers
      {
        'Authorization' => 'Bearer 1234',
        'Content-Type' => 'application/json',
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def config
      Eps::Configuration.instance
    end
  end
end
