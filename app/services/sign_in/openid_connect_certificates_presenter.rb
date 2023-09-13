# frozen_string_literal: true

module SignIn
  class OpenidConnectCertificatesPresenter
    def perform
      {
        keys: public_keys_jwk
      }
    end

    private

    def public_keys_jwk
      public_keys.map do |public_key|
        JWT::JWK.new(public_key, { alg: 'RS256', use: 'sig' }).export
      end
    end

    def public_keys
      public_keys = [private_key.public_key]
      old_key_file_path = Settings.sign_in.jwt_old_encode_key
      public_keys.push private_key(file_path: old_key_file_path).public_key if old_key_file_path
      public_keys
    end

    def private_key(file_path: Settings.sign_in.jwt_encode_key)
      OpenSSL::PKey::RSA.new(File.read(file_path))
    end
  end
end
