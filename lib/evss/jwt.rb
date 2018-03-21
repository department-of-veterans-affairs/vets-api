# frozen_string_literal: true

require 'jwt'
require 'securerandom'

module EVSS
  class Jwt
    ISSUER            = Settings.evss.jwt.issuer
    SIGNING_KEY       = Settings.evss.jwt.key
    SIGNING_ALGORITHM = 'HS256'
    EXP_WINDOW        = 5.minutes.to_i

    def initialize(user)
      @user = user
    end

    def encode
      JWT.encode(payload, SIGNING_KEY, SIGNING_ALGORITHM, typ: 'JWT')
    end

    private

    def payload
      {
        # reserved claims
        iat: Time.now.to_i,
        exp: Time.now.to_i + EXP_WINDOW,
        iss: ISSUER,
        jti: SecureRandom.uuid,

        # custom claims
        assuranceLevel: @user.loa[:current],
        email:          @user.email,
        firstName:      @user.first_name,
        middleName:     @user.middle_name,
        lastName:       @user.last_name,
        birthDate:      @user.birth_date, # takes the form YYYY-MM-DD
        gender:         @user.gender,
        prefix:         '', # TODO: i thought we had these in mvi...
        suffix:         '',
        correlationIds: Array(@user.mhv_correlation_id)
      }
    end
  end
end
