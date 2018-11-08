# frozen_string_literal: true

module Common
  # Cache Aside pattern for caching an ActiveRecord::Base db record in redis.
  #
  # Requires the model mixing it in to:
  #  - be an ActiveRecord::Base class
  #  - implement a #cache? method
  #
  # Expects the model mixing it in to:
  #   - set the config by calling redis and redis_ttl
  #   - call the do_cached_with with the desired unique key
  #   - require this class
  #
  # @see app/models/account.rb for sample usage
  #
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

      # Returns the cached ActiveRecord object that is cached by the passed in key.
      #
      # If the db record is already cached, it will return that.  If it is not,
      # it will cache the yielded record before returning it.
      #
      # @param key [String] The unique key that will be concatenated with the
      #   redis_namespace, to be used together as the Redis key
      # @return [ActiveRecord::Base] Returns a database record that inherits
      #   from ActiveRecord::Base
      #
      # rubocop:disable Security/MarshalLoad
      def self.do_cached_with(key:)
        cached = @redis_namespace.get(key)
        return Marshal.load(cached) if cached

        record = yield
        raise NoMethodError, 'The record class being cached must implement #cache?' unless record.respond_to?(:cache?)
        if record.cache?
          ttl = record.respond_to?(:record_ttl) ? record.record_ttl : @redis_namespace_ttl
          cache_record(key, record, ttl)
        end
        record
      end
      # rubocop:enable Security/MarshalLoad

      # Caches the passed ActiveRecord db record, caching it with the
      # passed key.  Also sets the caches expiration based on the
      # @redis_namespace_ttl that is set in the mixed in model class.
      #
      # @param key [String] The unique key that will be concatenated with the
      #   redis_namespace, to be used together as the Redis key
      # @param record [ActiveRecord::Base] The ActiveRecord::Base db record to be cached
      #
      def self.cache_record(key, record, ttl)
        serialized = Marshal.dump(record)

        @redis_namespace.set(key, serialized)
        @redis_namespace.expire(key, ttl)
      end
    end
  end
end
