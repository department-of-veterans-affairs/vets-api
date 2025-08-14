# frozen_string_literal: true

module TravelClaim
  class TokenClient < BaseClient
    GRANT_TYPE = 'client_credentials'

    def initialize(client_number = nil)
      super()
      @client_number = client_number || settings.travel_pay_client_id
    end

    def veis_token
      connection(server_url: settings.auth_url).post("/#{settings.tenant_id}/oauth2/v2.0/token") do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form({
                                         client_id: settings.travel_pay_client_id,
                                         client_secret: settings.travel_pay_client_secret,
                                         scope: settings.scope,
                                         grant_type: GRANT_TYPE
                                       })
      end
    end

    def system_access_token_v4(veis_access_token:, icn:)
      connection(server_url: settings.claims_url_v2).post('/api/v4/auth/system-access-token') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Correlation-ID'] = SecureRandom.uuid
        req.headers.merge!(claim_headers)
        req.headers['BTSSS-API-Client-Number'] = @client_number.to_s
        req.headers['Authorization'] = "Bearer #{veis_access_token}"
        req.body = { secret: settings.travel_pay_client_secret, icn: }.to_json
      end
    end
  end
end
