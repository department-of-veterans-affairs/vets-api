# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module PreferencesRedis
  # This class is responsible for caching a given User's Account record
  #
  class Account < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    #
    redis_config_key :user_account_details

    attr_accessor :user

    # .for_user takes a User object and caches an Account record for given User,
    # unless an Account record already exists in cache
    #
    # @param user [User] Persisted User object
    # @return [PreferencesRedis::Account] An instance of this class
    #
    def self.for_user(user)
      account = new
      account.user = user
      account.populate_from_redis

      account
    end

    # @return [String] cached Account record UUID
    #
    def account_uuid
      response&.user_account&.dig('uuid')
    end

    # This method allows us to populate the local instance of a
    # PreferencesRedis::Account object with the uuid necessary
    # to perform subsequent actions on the key such as deletion.
    #
    def populate_from_redis
      response_from_redis_or_service
    end

    # @return [Hash] with the Account attributes
    #
    def response
      @response ||= response_from_redis_or_service
    end

    private

    def response_from_redis_or_service
      do_cached_with(key: @user.uuid) do
        DatabaseCacheable::Account.new(@user)
      end
    end
  end
end
