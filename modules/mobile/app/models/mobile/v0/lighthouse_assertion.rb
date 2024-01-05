# frozen_string_literal: true

module Mobile
  module V0
    # Lighthouse OAuth assertion class used for establishing a LH session.
    #
    class LighthouseAssertion
      TTL = 300

      CLIENT_IDS = { health: Settings.lighthouse_health_immunization.client_id }.freeze

      AUD_CLAIM_URLS = { health: Settings.lighthouse_health_immunization.audience_claim_url }.freeze

      KEY_PATHS = { health: Settings.lighthouse_health_immunization.key_path }.freeze

      def initialize(api)
        @client_id = CLIENT_IDS[api]
        @aud_claim_url = AUD_CLAIM_URLS[api]
        @key_path = KEY_PATHS[api]
      end

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
          aud: @aud_claim_url,
          iss: @client_id,
          sub: @client_id,
          jti: SecureRandom.uuid,
          iat: Time.now.to_i,
          exp: Time.now.to_i + TTL
        }
      end

      def rsa_key
        OpenSSL::PKey::RSA.new(File.read(@key_path))
      end
    end
  end
end
