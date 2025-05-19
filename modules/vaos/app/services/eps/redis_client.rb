# frozen_string_literal: true

module Eps
  # RedisClient is responsible for interacting with the Redis cache
  # to store and retrieve tokens and referral information.
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_token_expiry

    REFERRAL_CACHE_KEY = 'vaos_eps_referral_identifier_'
    REFERRAL_CACHE_NAMESPACE = 'vaos-eps-cache'

    # Initializes the RedisClient with settings.
    def initialize
      @settings = Settings.vaos.eps
    end

    # Retrieves the token from the Redis cache.
    #
    # @return [String, nil] the token if it exists, otherwise nil
    def token
      Rails.cache.read('token', namespace: 'eps-access-token')
    end

    # Saves the token to the Redis cache.
    #
    # @param token [String] the token to be saved
    # @return [Boolean] true if the write was successful, otherwise false
    def save_token(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'eps-access-token',
        expires_in: REDIS_CONFIG[:eps_access_token][:each_ttl]
      )
    end

    # # Saves referral data directly to the Redis cache.
    # # The data is stored using the referral_number from the referral_data hash.
    # # The data is stored as a Ruby hash.
    # #
    # # @param referral_data [Hash] The referral data to be cached
    # # @return [Boolean] True if the cache operation was successful
    def save_referral_data(referral_data:)
      Rails.cache.write(
        "#{REFERRAL_CACHE_KEY}#{referral_data[:referral_number]}",
        referral_data,
        namespace: REFERRAL_CACHE_NAMESPACE,
        expires_in: redis_token_expiry
      )
    end

    # Retrieves all stored attributes for a given referral number from the Redis cache.
    # Returns the entire cached hash for the referral.
    #
    # @param referral_number [String] The referral number associated with the cached data
    # @return [Hash, nil] The complete referral data hash if it exists, otherwise nil
    def fetch_referral_attributes(referral_number:)
      @referral_identifiers ||= Hash.new do |h, key|
        h[key] = Rails.cache.read(
          "#{REFERRAL_CACHE_KEY}#{key}",
          namespace: REFERRAL_CACHE_NAMESPACE
        )
      end
      @referral_identifiers[referral_number]
    end
  end
end
