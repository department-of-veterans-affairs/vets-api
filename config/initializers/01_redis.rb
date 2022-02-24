# frozen_string_literal: true

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config

class RedisDuplicator < Redis
  def initialize(secondary_redis, options = {})
    @secondary_redis = secondary_redis
    super(options)
  end

  def set(key, value, options = {})
    @secondary_redis.set(key, value, options)
    super
  end

  def del(*keys)
    @secondary_redis.del(keys)
    super
  end

  def expire(key, seconds)
    @secondary_redis.expire(key, seconds)
    super
  end
end

$redis = if Settings.redis.app_data.key?(:secondary_url)
                  secondary_redis = Redis.new(url: Settings.redis.app_data.secondary_url)
                  RedisDuplicator.new(secondary_redis, REDIS_CONFIG[:redis].to_hash)
                else
                  Redis.new(REDIS_CONFIG[:redis].to_hash)
                end

Redis.exists_returns_integer = true
