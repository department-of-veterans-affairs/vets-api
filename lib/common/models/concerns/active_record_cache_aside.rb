# frozen_string_literal: true

module Common
  module ActiveRecordCacheAside
    extend ActiveSupport::Concern

    REDIS_CONFIG = Rails.application.config_for(:redis).freeze

    included do
      unless self < ActiveRecord::Base
        raise ArgumentError, 'Class composing Common::ActiveRecordCacheAside must be an ActiveRecord'
      end

      def self.redis(namespace)
        @redis_namespace = Redis::Namespace.new(namespace, redis: Redis.current)
      end

      def self.redis_ttl(ttl)
        @redis_namespace_ttl = ttl
      end

      def self.do_cached_with(key:)
        cached = @redis_namespace.get(key)
        return Marshal.load(cached) if cached

        record = yield
        raise NoMethodError, 'The record class being cached must implement #cache?' unless record.respond_to?(:cache?)
        cache_record(key, record) if record.cache?
        record
      end

      def self.cache_record(key, record)
        serialized = Marshal.dump(record)

        @redis_namespace.set(key, serialized)
        @redis_namespace.expire(key, @redis_namespace_ttl)
      end
    end
  end
end
