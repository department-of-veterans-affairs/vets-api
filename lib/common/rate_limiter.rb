# frozen_string_literal: true

module Common
  class RateLimiter
    def initialize(namespace)
      @namespace = namespace
      @redis = Redis::Namespace.new(@namespace, redis: Redis.current)
    end

    def increment
      increment_with_expire(:threshold, @namespace['threshold_ttl'])
      increment_with_expire(:count, @namespace['count_ttl'])
    end

    def at_limit?
      @namespace['threshold_limit'] >= @redis.get(:threshold) || @namespace['count_limit'] > @redis.get(:count)
    end

    private

    def increment_with_expire(key, ttl)
      @redis.expire(key, ttl) if @redis.incr(key) == 1
    end
  end
end
