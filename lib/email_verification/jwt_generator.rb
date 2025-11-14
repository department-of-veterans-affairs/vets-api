# frozen_string_literal: true

module EmailVerification
  # JWT generator for email verification tokens
  class JwtGenerator
    VALIDITY_LENGTH = 30.minutes
    ALGORITHM = 'HS256'
    ISSUER = 'vets-api-email-verification'

    def initialize(user)
      @user = user
    end

    def encode_jwt
      JWT.encode(payload, secret, ALGORITHM, headers)
    end

    private

    def headers
      { typ: 'JWT', alg: ALGORITHM }
    end

    def payload
      {
        jti: SecureRandom.uuid,
        iat: Time.zone.now.to_i,
        exp: (Time.zone.now + VALIDITY_LENGTH).to_i,
        iss: ISSUER,
        uuid: @user.uuid,
        email: @user.email
      }
    end

    def secret
      Settings.email_verification.jwt_secret
    end
  end
end
