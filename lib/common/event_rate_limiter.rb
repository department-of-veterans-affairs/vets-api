# frozen_string_literal: true

module Common
  class EventRateLimiter
    def initialize(redis_namespace)
      @redis_namespace = redis_namespace
      raise ArgumentError, 'threshold_ttl must be lower than count_ttl' if threshold_ttl_exceeds_count_ttl?

      @redis = Redis::Namespace.new(@redis_namespace['namespace'], redis: Redis.current)
    end

    def increment
      increment_with_expire(:threshold, @redis_namespace['threshold_ttl'])
      increment_with_expire(:count, @redis_namespace['count_ttl'])
    end

    def at_limit?
      threshold_exceeded? || count_exceeded?
    end

    private

    def threshold_ttl_exceeds_count_ttl?
      @redis_namespace['threshold_ttl'] > @redis_namespace['count_ttl']
    end

    def threshold_exceeded?
      @redis.get(:threshold).to_i >= @redis_namespace['threshold_limit']
    end

    def count_exceeded?
      @redis.get(:count).to_i >= @redis_namespace['count_limit']
    end

    def increment_with_expire(key, ttl)
      @redis.expire(key, ttl) if @redis.incr(key) == 1
    end
  end
end
