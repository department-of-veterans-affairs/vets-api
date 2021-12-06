# frozen_string_literal: true

require 'uri'
require 'base64'
require 'oj'
require 'openssl'

module VIC
  class URLHelper
    class << self
      def generate(id_attributes)
        params = id_attributes.traits
        params['timestamp'] = Time.now.utc.iso8601

        canonical_string = Oj.dump(params)
        params['signature'] = URLHelper.sign(canonical_string)
        {
          'url' => Settings.vic.url,
          'traits' => params
        }
      end

      def sign(canonical_string)
        digest = OpenSSL::Digest.new('SHA256')
        Base64.urlsafe_encode64(URLHelper.signing_key.sign(digest, canonical_string))
      end

      def signing_key
        @key ||= OpenSSL::PKey::RSA.new(File.read(Settings.vic.signing_key_path))
      end
    end
  end
end
