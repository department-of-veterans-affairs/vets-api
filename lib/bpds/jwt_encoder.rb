# frozen_string_literal: true

module BPDS
  class JwtEncoder
    VALIDITY_LENGTH = 30.minutes
    JWT_ENCODE_ALGORITHM = 'HS256'
    ISSUER = 'vets-api'

    # uses HMAC symmetric signing algorithm
    def get_token
      JWT.encode(payload, private_key, JWT_ENCODE_ALGORITHM, {
                   typ: 'JWT',
                   alg: 'HS256'
                 })
    end

    private

    def payload
      {
        iss: ISSUER, # issuer
        jti: SecureRandom.uuid, # random id to identify a unique JWT
        expires: expiration_time.to_i, # expiration date
        iat: created_time.to_i # issued_at
      }
    end

    def private_key
      Settings.bpds.jwt_secret
    end

    def expiration_time
      Time.zone.now + VALIDITY_LENGTH
    end

    def created_time
      Time.zone.now
    end
  end
end
