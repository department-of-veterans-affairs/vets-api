# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module PreferencesRedis
  class Account < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    #
    redis_config_key :user_account_details

    attr_accessor :user

    def self.for_user(user)
      account = new
      account.user = user
      account.populate_from_redis

      account
    end

    def account_uuid
      response&.user_account&.dig('uuid')
    end

    def populate_from_redis
      response_from_redis_or_service
    end

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
