# frozen_string_literal: true

require 'common/models/redis_store'

module Common
  # Cache Aside pattern for caching responses in redis.
  # Requires the class mixing it in to be a Common::RedisStore and the
  # cached response class to implement an #ok? method.
  # If a model or service class is calling #do_cached_with make sure to require
  # the response class from that file
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
      cached_response(key) and return
      response = yield
      raise NoMethodError, 'The response class being cached must implement #ok?' unless response.respond_to?(:ok?)
      cache(key, response) if response.ok?
      response
    end

    def conditionally_cache_response(key:, request:, condition:)
      cached_response(key) and return
      response = request.()
      cache(key, response) if condition.(response)
      response
    end

    def cached_response(key)
      cached = self.class.find(key)
      cached.response if cached
    end

    def cache(key, response)
      self.attributes = { uuid: key, response: response }
      save
    end
  end
end
