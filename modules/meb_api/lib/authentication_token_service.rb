# frozen_string_literal: true

module MebApi
  class AuthenticationTokenService
    ALGORITHM_TYPE = 'RS256'
    SIGNING_KEY = Settings.dgi.jwt.private_key_path
    RSA_PRIVATE = OpenSSL::PKey::RSA.new(File.read(SIGNING_KEY))
    DECODING_KEY = Settings.dgi.jwt.public_key_path
    RSA_PUBLIC = OpenSSL::PKey::RSA.new(File.read(DECODING_KEY))

    def self.call
      payload = {
        # issued at time
        iat: Time.now.to_i,
        # JWT expiration time (5 minute maximum)
        exp: Time.now.to_i + (5 * 60)
      }

      JWT.encode payload, RSA_PRIVATE, ALGORITHM_TYPE
    end
  end
end
