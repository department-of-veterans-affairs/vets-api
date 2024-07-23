# frozen_string_literal: true

module Vye
  module DigestProtected
    module Common
      private

      def scrypt_config
        Vye
          .settings
          &.scrypt
          &.to_h
          &.slice(:salt, :N, :r, :p, :length)
          &.freeze
      end

      public

      def gen_digest(value)
        value&.then { |v| OpenSSL::KDF.scrypt(v, **scrypt_config) }
      end
    end
  end
end
