# frozen_string_literal: true

module Benchmark
  class Timer
    TTL = 3600

    def self.start(category, name, ttl = nil)
      key = "benchmark_#{category}_#{name}"
      Redis.current.multi do |redis|
        redis.set(key, Time.now.to_f)
        redis.expire(key, ttl || TTL)
      end
    end

    def self.stop(category, name, **extra)
      key = "benchmark_#{category}_#{name}"
      start = Redis.current.multi do |redis|
        redis.get(key)
        redis.del(key)
      end.first

      if start.nil?
        Rails.logger.warn("Could not find benchmark start for #{category}_#{name}")
        return
      end

      elapsed = (Time.now.to_f - start.to_f) * 1000
      StatsD.measure(category, elapsed, **extra)
    end
  end
end
