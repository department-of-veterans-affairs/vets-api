# frozen_string_literal: true

module TravelClaim
  class TokenClient < BaseClient
    GRANT_TYPE = 'client_credentials'

    def initialize(client_number = nil)
      super()
      @client_number = client_number || settings.travel_pay_client_id
    end

    def veis_token
      body = URI.encode_www_form({
                                   client_id: settings.travel_pay_client_id,
                                   client_secret: settings.travel_pay_client_secret,
                                   scope: settings.scope,
                                   grant_type: GRANT_TYPE
                                 })

      headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }

      perform(:post, "/#{settings.tenant_id}/oauth2/v2.0/token", body, headers)
    end

    def system_access_token_v4(veis_access_token:, icn:)
      body = { secret: settings.travel_pay_client_secret, icn: }

      headers = {
        'Content-Type' => 'application/json',
        'X-Correlation-ID' => SecureRandom.uuid,
        'BTSSS-API-Client-Number' => @client_number.to_s,
        'Authorization' => "Bearer #{veis_access_token}"
      }.merge(claim_headers)

      perform(:post, '/api/v4/auth/system-access-token', body, headers)
    end
  end
end
