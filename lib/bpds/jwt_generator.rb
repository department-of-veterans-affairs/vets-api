# frozen_string_literal: true

require 'common/client/jwt_generator'

module BPDS
  # Encoder to be used with BPDS service
  class JwtGenerator < Common::Client::JwtGenerator
    # expiration period
    VALIDITY_LENGTH = 30.minutes

    private

    # retrieve the secret from settings
    def private_key
      Settings.bpds.jwt_secret
    end
  end
end
