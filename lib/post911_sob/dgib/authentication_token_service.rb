# frozen_string_literal: true

module Post911SOB
  module DGIB
    class AuthenticationTokenService 
      ALGORITHM_TYPE = 'RS256'
      TYP = 'JWT'
      KID = 'sob'
      USE = 'sig'
      SIGNING_KEY = Settings.dgi.post911_sob.jwt.private_key_path
      RSA_PRIVATE = OpenSSL::PKey::RSA.new(File.read(SIGNING_KEY))
      DECODING_KEY = Settings.dgi.post911_sob.jwt.public_key_path
      RSA_PUBLIC = OpenSSL::PKey::RSA.new(File.read(DECODING_KEY))

      def self.call
        payload = {
          nbf: Time.now.to_i,
          exp: Time.now.to_i + (5 * 60),
          realm_access: {
            roles: ['SOB']
          }
        }

        header_fields = { kid: KID, typ: TYP }

        JWT.encode(payload, RSA_PRIVATE, ALGORITHM_TYPE, header_fields)
      end
    end
  end
end
