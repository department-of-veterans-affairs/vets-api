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
      def token(api)
        JWT.encode(claims(api), rsa_key, 'RS512')
      end

      private

      def claims(api)
        {
          aud: aud_urls[api],
          iss: Settings.mobile_lighthouse.client_id,
          sub: Settings.mobile_lighthouse.client_id,
          jti: SecureRandom.uuid,
          iat: Time.now.to_i,
          exp: Time.now.to_i + TTL
        }
      end

      def aud_urls
        { health: Settings.mobile_lighthouse.health.aud_claim_url,
          letters: Settings.mobile_lighthouse.letters.aud_claim_url }
      end

      def rsa_key
        OpenSSL::PKey::RSA.new(File.read(Settings.mobile_lighthouse.key_path))
      end
    end
  end
end
