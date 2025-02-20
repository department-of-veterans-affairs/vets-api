# frozen_string_literal: true

module Common
  class JwtWrapper
    SIGNING_ALGORITHM = 'RS512'

    attr_reader :expiration, :settings

    delegate :key_path, :client_id, :kid, :audience_claim_url, to: :settings

    def initialize(service_settings)
      @settings = service_settings
      @expiration = 5
    end

    def sign_assertion
      JWT.encode(claims, rsa_key, SIGNING_ALGORITHM, jwt_headers)
    end

    def rsa_key
      @rsa_key ||= OpenSSL::PKey::RSA.new(File.read(key_path))
    end

    private

    def claims
      {
        iss: client_id,
        sub: client_id,
        aud: audience_claim_url,
        iat: Time.zone.now.to_i,
        exp: expiration.minutes.from_now.to_i
      }
    end

    def jwt_headers
      {
        kid:,
        typ: 'JWT',
        alg: SIGNING_ALGORITHM
      }
    end
  end
end
