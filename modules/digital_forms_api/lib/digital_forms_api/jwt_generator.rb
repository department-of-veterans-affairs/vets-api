# frozen_string_literal: true

module DigitalFormsApi
  class JwtGenerator
    # expiration period
    VALIDITY_LENGTH = 30.minutes

    # algorithm to be used
    ALGORITHM = 'HS256'

    # issuer constant
    ISSUER = 'vets-api'

    def initialize(private_key:)
      @private_key = private_key
    end

    def generate(payload)
      JWT.encode(payload, private_key, ALGORITHM)
    end

    private

    attr_reader :private_key
  end
end
