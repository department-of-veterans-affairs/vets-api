# frozen_string_literal: true

module RedisCaching
  extend ActiveSupport::Concern

  class_methods do
    def redis_config(config)
      @redis_namespace = config[:namespace]
      @redis_ttl = config[:each_ttl]
      @redis = Redis::Namespace.new(@redis_namespace, redis: $redis)
    end

    def get_cached(key)
      result = @redis.get(key)
      return nil unless result

      data = JSON.parse(result)

      if data.is_a?(Array)
        data.map { |i| new(i.deep_symbolize_keys) }
      else
        new(data.symbolize_keys)
      end
    end

    def set_cached(key, data)
      if data
        @redis.set(key, data.to_json)
        @redis.expire(key, @redis_ttl)
      else
        Rails.logger.info('Attempted to set nil data in redis cache')
      end
    end

    def clear_cache(key)
      @redis.del(key)
    end

    def time_until_5am_utc
      now = Time.now.utc
      five_am_utc = Time.utc(now.year, now.month, now.day, 5)
      five_am_utc += 1.day if now >= five_am_utc
      five_am_utc - now
    end
  end
end
