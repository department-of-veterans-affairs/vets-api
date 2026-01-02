# frozen_string_literal: true

module TravelClaim
  ##
  # Client for acquiring authentication tokens from VEIS and BTSSS v4 systems.
  #
  # Handles OAuth2 client credentials flow for VEIS tokens and patient-specific
  # BTSSS v4 system access tokens. Uses BaseClient's perform method for circuit
  # breaker protection.
  #
  class TokenClient < BaseClient
    # OAuth2 grant type for client credentials flow
    GRANT_TYPE = 'client_credentials'

    ##
    # Initializes the token client with an optional client number.
    #
    # @param client_number [String, nil] Optional client number for BTSSS API calls.
    #   Defaults to the configured travel_pay_client_id if not provided.
    #
    def initialize(client_number = nil)
      super()
      @client_number = client_number || settings.travel_pay_client_id
    end

    ##
    # Obtains a VEIS access token using OAuth2 client credentials flow.
    #
    # This token is required for subsequent BTSSS v4 system access token requests
    # and has a limited lifespan. The response contains the access token and
    # expiration information.
    #
    # @return [Faraday::Response] Response containing the OAuth2 token data
    # @raise [Common::Exceptions::BackendServiceException] If the token request fails
    #
    def veis_token
      body = URI.encode_www_form({
                                   client_id: settings.travel_pay_client_id,
                                   client_secret: settings.travel_pay_client_secret,
                                   grant_type: GRANT_TYPE
                                 })

      headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }

      perform(:post, "/#{settings.tenant_id}/oauth2/v2.0/token", body, headers)
    end

    ##
    # Obtains a BTSSS v4 system access token for a specific patient.
    #
    # This patient-specific token is required for all Travel Claim API operations
    # and provides access to the patient's travel claim data. The token is tied
    # to the provided ICN (Integrated Control Number).
    #
    # @param veis_access_token [String] Valid VEIS access token from veis_token method
    # @param icn [String] Patient's Integrated Control Number
    # @return [Faraday::Response] Response containing the system access token
    # @raise [Common::Exceptions::BackendServiceException] If the token request fails
    #
    def system_access_token_v4(veis_access_token:, icn:)
      body = { secret: settings.travel_pay_client_secret, icn: }

      headers = {
        'Content-Type' => 'application/json',
        'X-Correlation-ID' => SecureRandom.uuid,
        'BTSSS-API-Client-Number' => @client_number.to_s,
        'Authorization' => "Bearer #{veis_access_token}"
      }.merge(claim_headers)

      perform(:post, "#{settings.claims_base_path}/api/v4/auth/system-access-token", body, headers)
    end
  end
end
