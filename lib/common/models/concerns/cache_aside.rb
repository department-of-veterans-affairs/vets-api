# frozen_string_literal: true

require 'common/models/redis_store'

module Common
  # Cache Aside pattern for caching responses in redis.
  # Requires the class mixing it in to be a Common::RedisStore and the
  # cached response class to implement a #cache? method.

  module CacheAside
    extend ActiveSupport::Concern

    REDIS_CONFIG = Rails.application.config_for(:redis).freeze

    included do
      unless self < Common::RedisStore
        raise ArgumentError, 'Class composing Common::CacheAside must be a Common::RedisStore'
      end

      def self.redis_config_key(key)
        redis_store REDIS_CONFIG[key.to_s]['namespace']
        redis_ttl REDIS_CONFIG[key.to_s]['each_ttl']
        redis_key :uuid
      end
      attribute :uuid
      attribute :response
    end

    def do_cached_with(key:)
      cached = self.class.find(key)
      if cached
        set_attributes(key, cached.response)
        return cached.response
      end

      response = yield
      raise NoMethodError, 'The response class being cached must implement #cache?' unless response.respond_to?(:cache?)

      cache(key, response) if response.cache?
      response
    end

    def cache(key, response)
      set_attributes(key, response)
      save
    end

    private

    def set_attributes(key, response)
      self.attributes = { uuid: key, response: response }
    end
  end
end
