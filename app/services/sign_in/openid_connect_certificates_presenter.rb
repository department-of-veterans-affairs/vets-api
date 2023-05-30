# frozen_string_literal: true

module SignIn
  class OpenidConnectCertificatesPresenter
    def perform
      {
        keys: [public_key_jwk.export]
      }
    end

    private

    def public_key_jwk
      JWT::JWK.new(public_key, { alg: 'RS256', use: 'sig' })
    end

    def public_key
      private_key.public_key
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key))
    end
  end
end
