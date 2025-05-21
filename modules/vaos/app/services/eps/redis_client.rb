# frozen_string_literal: true

module Eps
  # RedisClient is responsible for interacting with the Redis cache
  # to store and retrieve tokens.
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_token_expiry

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
  end
end
