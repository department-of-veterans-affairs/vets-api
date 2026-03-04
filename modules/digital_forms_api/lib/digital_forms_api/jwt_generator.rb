# frozen_string_literal: true

module DigitalFormsApi
  # @see https://www.jwt.io/introduction#when-to-use-json-web-tokens
  #
  # Usage:
  # Prior to use, Settings.digital_forms_api.jwt_secret must be set.
  # API requests will fail even with a valid token unless on the VA API.
  #
  # Create token:
  # > require 'digital_forms_api/jwt_generator'
  # > encoder = DigitalFormsApi::JwtGenerator.new
  # > token = encoder.encode_jwt
  class JwtGenerator
    # Algorithm used to encode and decode the JWT
    ALGORITHM = 'HS256'

    # Issuer assigned
    ISSUER = 'vets-api'

    # Application
    APPLICATION = 'VAGOV'

    # Number of seconds for which the JWT is valid
    VALIDITY_LENGTH = 900.seconds # == 15.minutes

    # VBMS user logged in to the application; if no user interaction needs to be a system user
    USER_ID = 'VAGOVSYSACCT'

    # Station for above user
    STATION_ID = '283'

    # static method
    # @see #encode_jwt
    def self.encode_jwt
      new.encode_jwt
    end

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
        # applicationID MUST be the same as the issuer for tracking purposes
        applicationID: APPLICATION,
        userID: USER_ID,
        stationID: STATION_ID
      }
    end

    # retrieve the secret from settings
    def private_key
      Settings.digital_forms_api.jwt_secret
    end

    # set the token created time
    def created_time
      @created_time = Time.zone.now
    end

    # set the token expiration date
    def expiration_time
      @created_time + VALIDITY_LENGTH
    end
  end
end
