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
            @redis = Redis::Namespace.new(@redis_namespace, redis: Redis.current)
          end

          def get_cached(user)
            result = @redis.get(user.uuid)
            return nil unless result

            data = JSON.parse(result)
            data.map { |i| new(i.deep_symbolize_keys) }
          end

          def set_cached(user, data)
            @redis.set(user.uuid, data.to_json)
            @redis.expire(user.uuid, @redis_ttl)
          end
        end
      end
    end
  end
end
