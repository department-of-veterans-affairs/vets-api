# frozen_string_literal: true

module Ccra
  # Ccra::RedisClient provides a caching mechanism for CCRA referral data.
  # It stores and retrieves referral data from Redis, using a configurable expiration time.
  # All cached data is stored with the REFERRAL_CACHE_NAMESPACE and expires based on redis_referral_expiry setting.
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_referral_expiry

    REFERRAL_CACHE_KEY = 'vaos_ccra_referral_'
    BOOKING_START_TIME_CACHE_KEY = 'vaos_ccra_booking_start_time_'
    REFERRAL_CACHE_NAMESPACE = 'vaos-ccra-cache'

    # Initializes the RedisClient with settings.
    # Settings are loaded from Settings.vaos.ccra configuration.
    #
    # @return [Ccra::RedisClient] A new instance of RedisClient
    def initialize
      @settings = Settings.vaos.ccra
    end

    # Saves referral data to the Redis cache.
    # The data is stored as JSON with a compound key combining ICN and referral ID.
    #
    # @param id [String] The referral ID to use as part of the cache key
    # @param icn [String] The ICN of the patient to use as part of the cache key
    # @param referral_data [Object] The referral data to be cached (must respond to to_json)
    # @return [Boolean] true if the cache operation was successful
    def save_referral_data(id:, icn:, referral_data:)
      cache_key = generate_cache_key(id, icn)
      Rails.cache.write(
        cache_key,
        referral_data.to_json,
        namespace: REFERRAL_CACHE_NAMESPACE,
        expires_in: redis_referral_expiry
      )
    end

    # Saves booking start time to the Redis cache using referral number as key.
    # The booking start time is used to track when a referral booking process began.
    #
    # @param referral_number [String] The referral number to use as the cache key
    # @param booking_start_time [Float] Unix timestamp (seconds since epoch) representing when the booking started
    # @return [Boolean] true if the cache operation was successful
    def save_booking_start_time(referral_number:, booking_start_time:)
      cache_key = generate_booking_start_time_cache_key(referral_number)
      Rails.cache.write(
        cache_key,
        booking_start_time,
        namespace: REFERRAL_CACHE_NAMESPACE,
        expires_in: redis_referral_expiry,
        serializer: JSON
      )
    end

    # Retrieves booking start time from the Redis cache.
    #
    # @param referral_number [String] The referral number to lookup
    # @return [Float, nil] The Unix timestamp of when the booking started if found, nil otherwise
    def fetch_booking_start_time(referral_number:)
      cache_key = generate_booking_start_time_cache_key(referral_number)
      Rails.cache.read(
        cache_key,
        namespace: REFERRAL_CACHE_NAMESPACE,
        serializer: JSON
      )
    end

    # Retrieves referral data from the Redis cache.
    # If found, the cached JSON data is deserialized into a ReferralDetail object.
    #
    # @param id [String] The referral ID
    # @param icn [String] The ICN of the patient
    # @return [ReferralDetail, nil] A ReferralDetail object if found in cache, nil otherwise
    def fetch_referral_data(id:, icn:)
      cache_key = generate_cache_key(id, icn)
      json_data = Rails.cache.read(
        cache_key,
        namespace: REFERRAL_CACHE_NAMESPACE
      )
      json_data ? ReferralDetail.new.from_json(json_data) : nil
    end

    # Clears referral data from the Redis cache for a specific referral.
    #
    # @param id [String] The referral ID to clear
    # @param icn [String] The ICN of the patient
    # @return [Boolean] true if the key was found and deleted, false otherwise
    def clear_referral_data(id:, icn:)
      cache_key = generate_cache_key(id, icn)
      Rails.cache.delete(
        cache_key,
        namespace: REFERRAL_CACHE_NAMESPACE
      )
    end

    private

    # Generates a consistent cache key for a referral.
    # The key format is "#{REFERRAL_CACHE_KEY}#{icn}_#{id}"
    #
    # @param id [String] The referral ID
    # @param icn [String] The ICN of the patient
    # @return [String] The generated cache key
    def generate_cache_key(id, icn)
      "#{REFERRAL_CACHE_KEY}#{icn}_#{id}"
    end

    # Generates a consistent cache key for a booking start time.
    #
    # @param referral_number [String] The referral number
    # @return [String] The generated cache key in the format "#{BOOKING_START_TIME_CACHE_KEY}#{referral_number}"
    def generate_booking_start_time_cache_key(referral_number)
      "#{BOOKING_START_TIME_CACHE_KEY}#{referral_number}"
    end
  end
end
