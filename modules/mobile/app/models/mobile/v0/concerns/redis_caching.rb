# frozen_string_literal: true

module Mobile
  module V0
    module Concerns
      module RedisCaching
        extend ActiveSupport::Concern

        class_methods do
          def redis_config(config)
            @redis_namespace = config[:namespace]
            @redis_ttl = config[:each_ttl]
            @redis = Redis::Namespace.new(@redis_namespace, redis: $redis)
          end

          def get_cached(user)
            result = @redis.get(user.uuid)
            return nil unless result

            data = JSON.parse(result)

            if data.is_a?(Array)
              data.map { |i| new(i.deep_symbolize_keys) }
            else
              new(data.symbolize_keys)
            end
          end

          def set_cached(user, data, ttl = nil)
            return unless data

            @redis.set(user.uuid, data.to_json)
            @redis.expire(user.uuid, ttl || @redis_ttl)
          end

          def clear_cache(user)
            @redis.del(user.uuid)
          end
        end
      end
    end
  end
end
