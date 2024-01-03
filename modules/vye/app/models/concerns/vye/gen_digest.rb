# frozen_string_literal: true

require 'base64'
require 'openssl'

module Vye
  module GenDigest
    extend ActiveSupport::Concern

    module Common
      def self.get_gen_digest_config
        Settings.vye.scrypt.to_h
                .slice(*%i[salt N r p length])
                .freeze
      end

      GEN_DIGEST_CONFIG = Flipper.enabled?(:vye_load_scrypt_config) ? get_gen_digest_config : nil

      def gen_digest(value)
        value&.then { |v| Base64.encode64(OpenSSL::KDF.scrypt(v, **GEN_DIGEST_CONFIG)).strip }
      end
    end

    included do
      extend Common
      include Common
    end
  end
end
