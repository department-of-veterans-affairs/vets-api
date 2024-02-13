# frozen_string_literal: true

require 'base64'
require 'openssl'

module Vye
  module GenDigest
    extend ActiveSupport::Concern

    module Common
      def scrypt_config
        @scrypt_config ||= get_scrypt_config
      end

      def gen_digest(value)
        value&.then { |v| Base64.encode64(OpenSSL::KDF.scrypt(v, **scrypt_config)).strip }
      end

      private

      def get_scrypt_config
        settings = Settings

        if Rails.env.test?
          settings =
            Config.load_files(
              Rails.root / 'config/settings.yml',
              Vye::Engine.root / 'config/settings/test.yml'
            )
        end

        extract_scrypt_config settings
      end

      def extract_scrypt_config(settings)
        settings
          &.vye
          &.scrypt
          &.to_h
          &.slice(:salt, :N, :r, :p, :length)
          &.freeze
      end
    end

    included do
      extend Common
      include Common
    end
  end
end
