# frozen_string_literal: true

module Auth
  module ClientCredentials
    class JWTGenerator
      TTL = 300

      def self.iat
        Time.now.to_i
      end

      def self.build_claims(client_id, aud)
        {
          iss: client_id,
          sub: client_id,
          aud:,
          iat:,
          exp: iat + TTL
        }
      end

      def self.build_rsa_instance(key_location)
        key = File.exist?(key_location) ? File.read(key_location) : key_location

        OpenSSL::PKey::RSA.new(key)
      end

      def self.generate_token(client_id, aud_claim_url, key_location, kid = nil)
        claims = build_claims(client_id, aud_claim_url)
        rsa_instance = build_rsa_instance(key_location)
        headers = {}
        headers[:kid] = kid if kid.present?

        JWT.encode(claims, rsa_instance, 'RS256', headers)
      end
    end
  end
end
