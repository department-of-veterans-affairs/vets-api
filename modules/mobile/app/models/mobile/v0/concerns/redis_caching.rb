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
            @redis.get(user.uuid)
          end

          def set_cached(user, json)
            @redis.set(user.uuid, json)
            @redis.expire(user.uuid, @redis_ttl)
          end
        end
      end
    end
  end
end
