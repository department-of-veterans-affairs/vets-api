# frozen_string_literal: true

module Ccra
  # Ccra::RedisClient provides a caching mechanism for CCRA referral data.
  # It stores and retrieves referral data from Redis, using a configurable expiration time.
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_referral_expiry

    REFERRAL_CACHE_KEY = 'vaos_ccra_referral_'
    REFERRAL_CACHE_NAMESPACE = 'vaos-ccra-cache'

    # Initializes the RedisClient with settings.
    #
    # @return [Ccra::RedisClient] A new instance of RedisClient
    def initialize
      @settings = Settings.vaos.ccra
    end

    # Saves referral data to the Redis cache.
    #
    # @param id [String] The referral ID to use as the cache key
    # @param icn [String] The ICN of the patient
    # @param referral_data [Object] The referral data to be cached
    # @return [Boolean] True if the cache operation was successful
    def save_referral_data(id:, icn:, referral_data:)
      cache_key = generate_cache_key(id, icn)
      Rails.cache.write(
        cache_key,
        referral_data.to_json,
        namespace: REFERRAL_CACHE_NAMESPACE,
        expires_in: redis_referral_expiry
      )
    end

    # Retrieves referral data from the Redis cache.
    #
    # @param id [String] The referral ID
    # @param icn [String] The ICN of the patient
    # @return [Object, nil] The cached referral data if it exists, otherwise nil
    def fetch_referral_data(id:, icn:)
      cache_key = generate_cache_key(id, icn)
      json_data = Rails.cache.read(
        cache_key,
        namespace: REFERRAL_CACHE_NAMESPACE
      )
      json_data ? ReferralDetail.new.from_json(json_data) : nil
    end

    private

    # Generates a consistent cache key for a referral.
    #
    # @param id [String] The referral ID
    # @param icn [String] The ICN of the patient
    # @return [String] The generated cache key
    def generate_cache_key(id, icn)
      "#{REFERRAL_CACHE_KEY}#{icn}_#{id}"
    end
  end
end
