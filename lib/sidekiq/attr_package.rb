# frozen_string_literal: true

module Sidekiq
  class AttrPackage
    REDIS_NAMESPACE = 'sidekiq_attr_package'

    class << self
      # Create a new attribute package
      # @param expires_in [Integer] the expiration time in days
      # @param attrs [Hash] the attributes to be stored
      # @return [String] the key of the stored attributes
      def create(expires_in: 7.days, **attrs)
        json_attrs = attrs.to_json
        key = SecureRandom.hex(32)

        redis.set(key, json_attrs, ex: expires_in)

        key
      rescue => e
        raise AttrPackageError.new('create', e.message)
      end

      # Find an attribute package by key
      # @param key [String] the key of the attribute package
      # @return [Hash, nil] the found attributes, or nil if not found
      def find(key)
        json_value = redis.get(key)
        return nil unless json_value

        JSON.parse(json_value, symbolize_names: true)
      rescue => e
        raise AttrPackageError.new('find', e.message)
      end

      # Delete an attribute package by key
      # @param key [String] the key of the attribute package
      # @return [Integer] the number of keys deleted
      def delete(key)
        redis.del(key)
      rescue => e
        raise AttrPackageError.new('delete', e.message)
      end

      private

      def redis
        @redis ||= Redis::Namespace.new(REDIS_NAMESPACE, redis: $redis) # rubocop:disable ThreadSafety/ClassInstanceVariable
      end
    end
  end

  class AttrPackageError < StandardError
    def initialize(method, message)
      super("[Sidekiq] [AttrPackage] #{method} error: #{message}")
    end
  end
end
