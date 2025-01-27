# frozen_string_literal: true

module Eps
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.eps'
    REDIS_TOKEN_KEY = REDIS_CONFIG[:eps_access_token][:namespace]
    REDIS_TOKEN_TTL = REDIS_CONFIG[:eps_access_token][:each_ttl]

    def headers
      {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def config
      @config ||= Eps::Configuration.instance
    end

    def get_token
      with_monitoring do
        perform(:post,
                config.access_token_url,
                token_params,
                token_headers)
      end
    end

    def token
      Rails.cache.fetch(REDIS_TOKEN_KEY, expires_in: REDIS_TOKEN_TTL) do
        token_response = get_token
        parse_token_response(token_response)
      end
    end

    private

    def parse_token_response(response)
      raise TokenError, 'Invalid token response' if response.body.nil? || response.body['access_token'].blank?

      response.body['access_token']
    end

    def token_params
      URI.encode_www_form({
                            grant_type: config.grant_type,
                            scope: config.scopes,
                            client_assertion_type: config.client_assertion_type,
                            client_assertion: JwtWrapper.new.sign_assertion
                          })
    end

    def token_headers
      { 'Content-Type' => 'application/x-www-form-urlencoded' }
    end

    def patient_id
      @patient_id ||= user.icn
    end

    class TokenError < StandardError; end
  end
end
