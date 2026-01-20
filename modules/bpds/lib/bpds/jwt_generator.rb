# frozen_string_literal: true

module BPDS
  # Encoder to be used with BPDS service
  # @see https://www.jwt.io/introduction#when-to-use-json-web-tokens
  class JwtGenerator
    # expiration period
    VALIDITY_LENGTH = 30.minutes

    # algorithm to be used
    ALGORITHM = 'HS256'

    # issuer constant
    ISSUER = 'vets-api'

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

    # the generated payload to be encoded
    def payload
      {
        jti: SecureRandom.uuid, # random id to identify a unique JWT
        iat: created_time.to_i,
        expires: expiration_time.to_i,
        iss: ISSUER
      }
    end

    # retrieve the secret from settings
    def private_key
      Settings.bpds.jwt_secret
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
