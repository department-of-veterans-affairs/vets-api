# frozen_string_literal: true

require_relative '../concerns/token_authentication'
require_relative '../concerns/jwt_wrapper'

module Eps
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include Concerns::TokenAuthentication

    STATSD_KEY_PREFIX = 'api.eps'
    REDIS_TOKEN_KEY = REDIS_CONFIG[:eps_access_token][:namespace]
    REDIS_TOKEN_TTL = REDIS_CONFIG[:eps_access_token][:each_ttl]

    def config
      @config ||= Eps::Configuration.instance
    end

    private

<<<<<<< HEAD
=======
    def parse_token_response(response)
      raise TokenError, 'Invalid token response' if response.body.nil? || response.body[:access_token].blank?

      response.body[:access_token]
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

>>>>>>> origin/master
    def patient_id
      @patient_id ||= user.icn
    end
  end
end
