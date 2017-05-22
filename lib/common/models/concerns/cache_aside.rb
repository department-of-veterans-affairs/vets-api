# frozen_string_literal: true
require 'common/models/redis_store'

module Common
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
      return cached.response if cached
      response = yield
      raise NoMethodError, 'The response class being cached must implement #ok?' unless response.respond_to?(:ok?)
      cache(key, response) if response.ok?
      response
    end

    def cache(key, response)
      self.attributes = { uuid: key, response: response }
      save
    end
  end
end
