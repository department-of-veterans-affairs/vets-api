# frozen_string_literal: true

require 'active_support/concern'

module Vets
  module Collections
    module Cacheable
      extend ActiveSupport::Concern

      CACHE_NAMESPACE = 'common_collection'
      CACHE_DEFAULT_TTL = 3600 # default to 1 hour

      class_methods do
        # rubocop:disable ThreadSafety/ClassInstanceVariable
        def redis_namespace
          @redis_namespace ||= Redis::Namespace.new(CACHE_NAMESPACE, redis: $redis)
        end
        # rubocop:enable ThreadSafety/ClassInstanceVariable

        def fetch(klass, cache_key: nil, ttl: CACHE_DEFAULT_TTL, &block)
          raise ArgumentError, 'No block given' unless block

          results = block.call
          records = results[:data]
          metadata = results[:metadata] || {}
          errors = results[:errors] || {}

          return new(records, klass, metadata:, errors:) unless cache_key

          json_string = redis_namespace.get(cache_key)

          return build_and_cache(records, klass, metadata, errors, { cache_key:, ttl: }) if json_string.nil?

          from_cache(klass, json_string, cache_key)
        end

        def cache(json_hash, cache_key, ttl)
          redis_namespace.set(cache_key, json_hash)
          redis_namespace.expire(cache_key, ttl)
        end

        def bust(cache_keys)
          Array.wrap(cache_keys).map { |key| redis_namespace.del(key) }
        end

        private

        def build_and_cache(results, klass, metadata, errors, caching)
          cache_key = caching[:cache_key]
          collection = new(results, klass, metadata:, errors:, cache_key:)
          cache(collection.serialize, cache_key, caching[:ttl])
          collection
        end

        def from_cache(klass, json_string, cache_key)
          json_hash = Oj.load(json_string)
          data = json_hash[:data]
          metadata = json_hash[:metadata]
          errors = json_hash[:errors]
          new(data, klass, metadata:, errors:, cache_key:)
        end
      end

      def redis_namespace
        @redis_namespace ||= self.class.redis_namespace
      end

      def bust
        self.class.bust(@cache_key) if cached?
      end

      def cached?
        @cache_key.present?
      end

      def ttl
        @cache_key.present? ? redis_namespace.ttl(@cache_key) : nil
      end
    end
  end
end
