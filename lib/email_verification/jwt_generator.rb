# frozen_string_literal: true

module EmailVerification
  class JwtGenerator
    TOKEN_VALIDITY_DURATION = 30.minutes
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
        exp: (Time.zone.now + TOKEN_VALIDITY_DURATION).to_i,
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
