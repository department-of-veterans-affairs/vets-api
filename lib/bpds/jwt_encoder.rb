# frozen_string_literal: true

module BPDS
  # Encoder to be used with BPDS service
  class JwtEncoder
    # expiration period
    VALIDITY_LENGTH = 30.minutes

    # algorithm to be used
    JWT_ENCODE_ALGORITHM = 'HS256'

    # issuer constant
    ISSUER = 'vets-api'

    # uses HMAC symmetric signing algorithm
    def get_token
      JWT.encode(payload, private_key, JWT_ENCODE_ALGORITHM, {
                   typ: 'JWT',
                   alg: 'HS256'
                 })
    end

    private

    # the generated payload to be encoded
    def payload
      {
        iss: ISSUER, # issuer
        jti: SecureRandom.uuid, # random id to identify a unique JWT
        expires: expiration_time.to_i, # expiration date
        iat: created_time.to_i # issued_at
      }
    end

    # retrieve the secret from settings
    def private_key
      Settings.bpds.jwt_secret
    end

    # set the token expiration date (expires)
    def expiration_time
      Time.zone.now + VALIDITY_LENGTH
    end

    # set the token created time (iat)
    def created_time
      Time.zone.now
    end
  end
end
