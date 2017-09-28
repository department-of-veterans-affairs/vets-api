# frozen_string_literal: true
require 'uri'
require 'base64'
require 'oj'
require 'openssl'

module VIC
  class URLHelper
    class << self
      def generate_url(id_attributes)
        params = id_attributes.traits
        params['timestamp'] = Time.now.utc.iso8601

        canonical_string = Oj.dump(params)
        params['signature'] = URLHelper.sign(canonical_string)

        base_url = URI(Settings.vic.url)
        base_url.query = URI.encode_www_form(params)
        base_url.to_s
      end

      def sign(canonical_string)
        digest = OpenSSL::Digest::SHA256.new
        Base64.urlsafe_encode64(URLHelper.signing_key.sign(digest, canonical_string))
      end

      def signing_key
        @key ||= OpenSSL::PKey::RSA.new(File.read(Settings.vic.signing_key_path))
      end
    end
  end
end
