# frozen_string_literal: true
module TravelClaim
  class AuthManager < BaseClient
    attr_reader :redis_client, :check_in_session

    def initialize(check_in_session: nil)
      super()
      @check_in_session = check_in_session
      @redis_client = ::TravelClaim::RedisClient.build
    end

    # Returns a BTSSS system access token (v4)
    # If icn is nil, attempts to resolve from Redis using check_in_session
    def authorize(icn: nil)
      resolved_icn = resolve_icn(icn)
      raise ArgumentError, 'ICN not available' if resolved_icn.blank?

      veis_resp = veis_token
      veis_access_token = Oj.safe_load(veis_resp.body).fetch('access_token')

      v4_resp = system_access_token_v4(veis_access_token:, icn: resolved_icn)
      Oj.safe_load(v4_resp.body).dig('data', 'accessToken')
    end

    private

    def resolve_icn(passed_icn)
      return passed_icn if passed_icn.present?
      return nil if check_in_session.nil?

      redis_client.icn(uuid: check_in_session.uuid)
    end

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
  end
end
