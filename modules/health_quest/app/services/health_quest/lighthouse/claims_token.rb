# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    ##
    # An object responsible for handling JWT claims used for Lighthouse authentication
    #
    class ClaimsToken
      EXPIRATION_DURATION = 15
      SIGNING_ALGORITHM = 'RS512'
      TOKEN_PATH = '/v1/token'

      attr_reader :api

      ##
      # Builds a Lighthouse::ClaimsToken instance
      #
      # @param api [String] the Lighthouse api
      # @return [Lighthouse::ClaimsToken] an instance of this class
      #
      def self.build(api:)
        new(api:)
      end

      def initialize(opts)
        @api = opts[:api]
      end

      ##
      # Sign the claims JWT using a private key and algorithm
      #
      # @return [String]
      #
      def sign_assertion
        JWT.encode(claims, rsa_key, signing_algorithm)
      end

      ##
      # Builds the claims hash for the `sign_assertion` method
      #
      # @return [Hash]
      #
      def claims
        {
          aud: aud[api],
          iss:,
          sub:,
          jti: random_uuid,
          iat: issued_at_time,
          exp: expires_at_time
        }
      end

      def rsa_key
        @rsa_key ||= OpenSSL::PKey::RSA.new(File.read(private_key_path))
      end

      def aud
        {
          'pgd_api' => "#{lighthouse.pgd_aud_claim_url}#{TOKEN_PATH}",
          'health_api' => "#{lighthouse.health_aud_claim_url}#{TOKEN_PATH}"
        }
      end

      def iss
        lighthouse.claim_common_id
      end

      def sub
        lighthouse.claim_common_id
      end

      def random_uuid
        @random_uuid ||= SecureRandom.uuid
      end

      def issued_at_time
        @issued_at_time ||= Time.zone.now.to_i
      end

      def expires_at_time
        @expires_at_time ||= EXPIRATION_DURATION.minutes.from_now.to_i
      end

      def signing_algorithm
        SIGNING_ALGORITHM
      end

      def private_key_path
        lighthouse.key_path
      end

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
