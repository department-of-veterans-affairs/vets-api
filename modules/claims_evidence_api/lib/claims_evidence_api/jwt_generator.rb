# frozen_string_literal: true

require 'common/client/jwt_generator'

module ClaimsEvidenceApi
  # Usage:
  # Prior to use, Settings.claims_evidence_api.jwt_secret must be set.
  # API requests will fail even with a valid token unless on the VA API.
  # Create token:
  # > require 'claims_evidence_api/jwt_generator'
  # > encoder = ClaimsEvidenceApi::JwtGenerator.new
  # > token = encoder.encode_jwt
  # Use token:
  # > curl -X GET https://claimevidence-api-test.dev.bip.va.gov/api/v1/rest/swagger-ui.html \
  # > -- 'Authentication: Bearer [TOKEN]'
  class JwtGenerator < Common::Client::JwtGenerator
    # VBMS user logged in to the application; if no user interaction needs to be a system user
    USER_ID = 'VAGOVSYSACCT'
    # Station for above user
    STATION_ID = '283'

    private

    # Returns the payload for the JWT token
    def payload
      super.merge({
        # applicationID MUST be the same as the issuer for tracking purposes
        applicationID: ISSUER,
        userID: USER_ID,
        stationID: STATION_ID
      })
    end

    # retrieve the secret from settings
    def private_key
      Settings.claims_evidence_api.jwt_secret
    end
  end
end
