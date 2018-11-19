# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module PreferencesRedis
  class Cache < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    #
    redis_config_key :preferences

    attr_reader :code

    def initialize(code)
      @code = code
    end

    def self.for(code)
      instance = new(code)

      instance.response
    end

    def response
      @response ||= response_from_redis_or_service
    end

    private

    def response_from_redis_or_service
      do_cached_with(key: code) do
        PreferencesRedis::Response.for(code)
      end
    end
  end
end
