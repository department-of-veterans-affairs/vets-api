# frozen_string_literal: true

require 'base64'
require 'openssl'

module Vye
  module GenDigest
    extend ActiveSupport::Concern

    module Common
      module_eval do
        store = nil

        define_method :scrypt_config do
          store || extract_scrypt_config
        end

        define_method :extract_scrypt_config do |settings = Settings|
          return unless Flipper.enabled?(:vye_load_scrypt_config)

          store =
            settings
            &.vye
            &.scrypt
            &.to_h
            &.slice(:salt, :N, :r, :p, :length)
            &.freeze
        end
      end

      def gen_digest(value)
        value&.then { |v| Base64.encode64(OpenSSL::KDF.scrypt(v, **scrypt_config)).strip }
      end
    end

    included do
      extend Common
      include Common
    end
  end
end
