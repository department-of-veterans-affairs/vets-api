# frozen_string_literal: true

require 'jwt'

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
  # > -- 'Authentication: Bearer {token}'
  class JwtGenerator
    # Issuer assigned by Claim Evidence API team
    ISSUER = 'VAGOV'
    # VBMS user logged in to the application; if no user interaction needs to be a system user
    USER_ID = 'VAGOVSYSACCT'
    # Station for above user
    STATION_ID = '283'
    # Number of seconds for which the JWT is valid; should be limited to 15 minutes or less
    VALIDITY_LENGTH = 15.minutes
    # Algorithm used to encode and decode the JWT
    ALGORITHM = 'HS256'

    # Returns a JWT token for use in Bearer auth
    def encode_jwt
      JWT.encode(payload, private_key, ALGORITHM, headers)
    end

    private

    # Returns the headers for the JWT token
    def headers
      { typ: 'JWT', alg: ALGORITHM }
    end

    # Returns the payload for the JWT token
    def payload
      {
        jti: SecureRandom.uuid, # random id to identify a unique JWT
        iat: created_time.to_i,
        exp: expiration_time.to_i,
        iss: ISSUER,
        #  applicationID MUST be the same as the issuer for tracking purposes
        applicationID: ISSUER,
        userID: USER_ID,
        stationID: STATION_ID
      }
    end

    # set the token expiration date
    def expiration_time
      Time.zone.now + VALIDITY_LENGTH
    end

    # set the token created time
    def created_time
      Time.zone.now
    end

    # retrieve the secret from settings
    def private_key
      Settings.claims_evidence_api.jwt_secret
    end
  end
end
