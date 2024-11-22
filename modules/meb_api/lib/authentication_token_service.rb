# frozen_string_literal: true

module MebApi
  class AuthenticationTokenService
    ALGORITHM_TYPE = 'RS256'
    TYP = 'JWT'
    KID = 'vanotify'
    SIGNING_KEY = Settings.dgi.jwt.private_key_path
    RSA_PRIVATE = OpenSSL::PKey::RSA.new(File.read(SIGNING_KEY)) if File.exist?(SIGNING_KEY)
    DECODING_KEY = Settings.dgi.jwt.public_key_path
    RSA_PUBLIC = OpenSSL::PKey::RSA.new(File.read(DECODING_KEY)) if File.exist?(DECODING_KEY)

    def self.call
      payload = {
        # issued at time
        iat: Time.now.to_i,
        # JWT expiration time (5 minute maximum)
        exp: Time.now.to_i + (5 * 60)
      }

      header_fields = { kid: KID, typ: TYP }

      JWT.encode payload, RSA_PRIVATE, ALGORITHM_TYPE, header_fields
    end
  end
end
