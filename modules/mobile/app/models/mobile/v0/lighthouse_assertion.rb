# frozen_string_literal: true

module Mobile
  module V0
    # Lighthouse OAuth assertion class used for establishing a LH session.
    #
    class LighthouseAssertion
      TTL = 300

      # Encodes the Lighthouse claim as a JWT token.
      #
      # @return [String] the encoded token as JWT::Encode string
      #
      def token
        JWT.encode(claims, rsa_key, 'RS512')
      end

      private

      def claims
        {
          aud: Settings.lighthouse_health_immunization.audience_claim_url,
          iss: Settings.lighthouse_health_immunization.client_id,
          sub: Settings.lighthouse_health_immunization.client_id,
          jti: SecureRandom.uuid,
          iat: Time.now.to_i,
          exp: Time.now.to_i + TTL
        }
      end

      def rsa_key
        OpenSSL::PKey::RSA.new(File.read(Settings.lighthouse_health_immunization.key_path))
      end
    end
  end
end
