# frozen_string_literal: true
module TravelClaim
  class AuthManager < BaseClient
    attr_reader :redis_client, :check_in_session

    CACHE_NAMESPACE = 'check-in-travel-pay-cache'
    CACHE_KEY_PREFIX = 'travel_pay_v4_token'

    def initialize(check_in_session:)
      super()
      @check_in_session = check_in_session
      @redis_client = ::TravelClaim::RedisClient.build
    end

    # Returns a BTSSS system access token (v4) for the user associated with the check-in session
    # Caches token per ICN until expiry
    def authorize
      icn = redis_client.icn(uuid: check_in_session.uuid)
      raise ArgumentError, 'ICN not available for session' if icn.blank?

      cached = read_token(icn)
      return cached if cached.present?

      veis_resp = veis_token
      veis_access_token = Oj.safe_load(veis_resp.body).fetch('access_token')

      v4_resp = system_access_token_v4(veis_access_token:, icn:)
      access_token = Oj.safe_load(v4_resp.body).dig('data', 'accessToken')
      save_token(icn, access_token)
      access_token
    end

    private

    def veis_token
      connection(server_url: settings.auth_url).post("/#{settings.tenant_id}/oauth2/v2.0/token") do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form({
                                          client_id: settings.travel_pay_client_id,
                                          client_secret: settings.travel_pay_client_secret,
                                          scope: settings.scope,
                                          grant_type: 'client_credentials'
                                        })
      end
    end

    def system_access_token_v4(veis_access_token:, icn:)
      connection(server_url: settings.claims_url_v2).post('/api/v4/auth/system-access-token') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Correlation-ID'] = SecureRandom.uuid
        req.headers.merge!(claim_headers)
        req.headers['Authorization'] = "Bearer #{veis_access_token}"
        req.body = { secret: settings.travel_pay_client_secret, icn: }.to_json
      end
    end

    def read_token(icn)
      Rails.cache.read(cache_key(icn), namespace: CACHE_NAMESPACE)
    end

    def save_token(icn, token)
      ttl = settings.redis_token_expiry
      Rails.cache.write(cache_key(icn), token, namespace: CACHE_NAMESPACE, expires_in: ttl)
    end

    def cache_key(icn)
      "#{CACHE_KEY_PREFIX}:#{icn}"
    end

    def settings
      @settings ||= Settings.check_in.travel_reimbursement_api_v2
    end
  end
end
