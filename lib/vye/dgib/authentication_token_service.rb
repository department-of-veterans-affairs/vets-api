# frozen_string_literal: true

module Vye
  module DGIB
    class AuthenticationTokenService
      ALGORITHM_TYPE = 'RS256'
      # E & USE were provided by security team but may not be needed for JWT generation
      # They're typically used for JWK (JSON Web Key) format, not JWT headers
      # TODO: Check with security team if these can be removed
      E = 'AQAB'
      TYP = 'JWT'
      USE = 'sig'
      SIGNING_KEY = Settings.dgi.vye.jwt.private_key_path
      RSA_PRIVATE = OpenSSL::PKey::RSA.new(File.read(SIGNING_KEY))

      def self.call
        payload = {
          exp: 5.minutes.from_now.to_i, # JWT expiration time (5 minutes)
          nbf: Time.now.to_i,
          realm_access: {
            roles: ['VYE']
          }
        }

        header_fields = { kid: Settings.dgi.vye.jwt.kid, typ: TYP }

        JWT.encode payload, RSA_PRIVATE, ALGORITHM_TYPE, header_fields
      end
    end
  end
end
