# frozen_string_literal: true

require 'openssl'
require 'oidc/service'
module OIDC
  class KeyService
    @mutex = Mutex.new
    # Map from kid to OpenSSL::RSA::PKey for all current keys

    # rubocop:disable ThreadSafety/MutableClassInstanceVariable
    @current_keys = {}
    @cache_miss_kids = {}
    # rubocop:enable ThreadSafety/MutableClassInstanceVariable
    @expected_iss = nil
    KID_CACHE_PERIOD_SECS = 60
    KID_CACHE_MAX_SIZE = 10

    def self.get_key(expected_kid, expected_iss)
      @expected_iss = expected_iss
      found = @current_keys[expected_kid]
      if found.nil? && should_refresh?(expected_kid)
        refresh expected_kid
        found = @current_keys[expected_kid]
        update_missing_kid_cache(expected_kid) if found.nil?
      end
      found
    end

    def self.update_missing_kid_cache(kid)
      if @cache_miss_kids.length >= KID_CACHE_MAX_SIZE && !@cache_miss_kids.key?(kid)
        oldest_kid = @cache_miss_kids.min_by { |_, timestamp| timestamp }[0]
        @cache_miss_kids.delete oldest_kid
      end
      @cache_miss_kids[kid] = Time.now.utc
    end

    def self.should_refresh?(kid)
      last_miss = @cache_miss_kids[kid]
      last_miss.nil? || Time.now.utc - last_miss > KID_CACHE_PERIOD_SECS
    end

    def self.reset!
      @mutex.synchronize do
        @current_keys = {}
        @cache_miss_kids = {}
      end
    end

    def self.refresh(expected_kid)
      @mutex.synchronize do
        break if @current_keys[expected_kid].present?

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
      service = OIDC::Service.new
      key_response = service.oidc_jwks_keys(@expected_iss)
      key_response.body
    end

    def self.build_key(jwks_object)
      e = OpenSSL::BN.new(Base64.urlsafe_decode64(jwks_object['e']), 2)
      n = OpenSSL::BN.new(Base64.urlsafe_decode64(jwks_object['n']), 2)

      data_sequence = OpenSSL::ASN1::Sequence([OpenSSL::ASN1::Integer(n), OpenSSL::ASN1::Integer(e)])
      asn1 = OpenSSL::ASN1::Sequence(data_sequence)
      key = OpenSSL::PKey::RSA.new(asn1.to_der)

      [jwks_object['kid'], key]
    end
  end
end
