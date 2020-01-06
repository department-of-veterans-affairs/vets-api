# frozen_string_literal: true

require 'openssl'

module OIDC
  class KeyService
    @mutex = Mutex.new
    # Map from kid to OpenSSL::RSA::PKey for all current keys
    @current_keys = {}

    class << self
      attr_reader :current_keys
    end

    def self.get_key(expected_kid)
      found = @current_keys[expected_kid]
      if found.nil?
        refresh expected_kid
        found = @current_keys[expected_kid]
      end
      found
    end

    def self.refresh(expected_kid)
      @mutex.synchronize do
        break if current_keys[expected_kid].present?

        jwks_result = fetch_keys
        new_keys = {}
        jwks_result['keys'].each do |jwks_object|
          kid, key = build_key(jwks_object)
          new_keys[kid] = key.public_key
        end
        @current_keys = new_keys
      end
    end

    def self.fetch_keys
      okta = Okta::Service.new
      key_response = okta.oidc_jwks_keys
      key_response.body
    end

    def self.build_key(jwks_object)
      key = OpenSSL::PKey::RSA.new
      e = OpenSSL::BN.new(Base64.urlsafe_decode64(jwks_object['e']), 2)
      n = OpenSSL::BN.new(Base64.urlsafe_decode64(jwks_object['n']), 2)
      key.set_key(n, e, nil)
      [jwks_object['kid'], key]
    end
  end
end
