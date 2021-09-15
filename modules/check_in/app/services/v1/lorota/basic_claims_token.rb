# frozen_string_literal: true

module V1
  module Lorota
    class BasicClaimsToken
      SIGNING_ALGORITHM = 'RS256'

      extend Forwardable

      attr_reader :expiration, :settings, :check_in

      def_delegators :settings, :key_path

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v1
        @check_in = opts[:check_in]
        @expiration = 1440
      end

      def sign_assertion
        JWT.encode(claims, rsa_key, SIGNING_ALGORITHM)
      end

      def claims
        {
          aud: 'lorota',
          iss: 'vets-api',
          sub: check_in.uuid,
          scopes: ['read.basic'],
          iat: issued_at_time,
          exp: expires_at_time
        }
      end

      def rsa_key
        @rsa_key ||= OpenSSL::PKey::RSA.new(File.read(key_path))
      end

      def issued_at_time
        @issued_at_time ||= Time.zone.now.to_i
      end

      def expires_at_time
        @expires_at_time ||= expiration.minutes.from_now.to_i
      end
    end
  end
end
