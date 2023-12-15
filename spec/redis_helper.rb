require "redis"

module RedisHelper
  def self.included(rspec)
    rspec.around(:each, redis: true) do |example|
      with_clean_redis do
        example.run
      end
    end
  end

  def redis(&block)

    @redis ||= if Rails.env.test?
      require 'mock_redis'
      MockRedis.new
    else
      Redis.new(REDIS_CONFIG[:redis].to_h)
    end

  end

  def with_clean_redis(&block)
    redis.flushall
    begin
      yield
    ensure
      redis.flushall
    end
  end

end
