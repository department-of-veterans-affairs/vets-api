# frozen_string_literal: true

module Vye
  module DigestProtected
    module Common
      def gen_digest(value)
        value&.then { |v| OpenSSL::KDF.scrypt(v, **scrypt_config) }
      end

      private

      def settings
        if Rails.env.test?
          Config.load_files(
            Rails.root / 'config/settings.yml',
            Vye::Engine.root / 'config/settings/test.yml'
          )
        else
          Settings
        end
      end

      def scrypt_config
        settings
          &.vye
          &.scrypt
          &.to_h
          &.slice(:salt, :N, :r, :p, :length)
          &.freeze
      end
    end
  end
end
