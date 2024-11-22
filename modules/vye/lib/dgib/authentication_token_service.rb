# frozen_string_literal: true

module Vye
  module DGIB
    class AuthenticationTokenService
      puts "\n\n\n*** Private key path: #{Settings.dgi.vye.jwt.private_key_path}***\n\n\n"
      puts "\n\n\n***File exists? #{File.exist?(Settings.dgi.vye.jwt.private_key_path)}***\n\n\n"
      ALGORITHM_TYPE = 'RS256'
      E = 'AQAB'
      TYP = 'JWT'
      KID = 'vye'
      USE = 'sig'
      SIGNING_KEY = Settings.dgi.vye.jwt.private_key_path
      RSA_PRIVATE = OpenSSL::PKey::RSA.new(File.read(SIGNING_KEY)) if File.exist?(SIGNING_KEY)

      def self.call
        payload = {
          exp: Time.now.to_i + (5 * 60), # JWT expiration time (5 minutes)
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
