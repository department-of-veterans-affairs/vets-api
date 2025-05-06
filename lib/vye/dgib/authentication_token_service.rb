# frozen_string_literal: true

module Vye
  module DGIB
    class AuthenticationTokenService
      ALGORITHM_TYPE = 'RS256'
      E = 'AQAB'
      TYP = 'JWT'
      KID = 'vye'
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

        header_fields = { kid: KID, typ: TYP }

        JWT.encode payload, RSA_PRIVATE, ALGORITHM_TYPE, header_fields
      end
    end
  end
end
