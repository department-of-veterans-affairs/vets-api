# frozen_string_literal: true

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config
# This is raising deprecation warnings because a ActiveSupport::OrderedOptions won't support string keys in Rails 6.1

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

Redis.current = if Settings.redis&.duplicate_to_secondary
                  secondary_redis = Redis.new(host: Settings.redis_secondary.host, port: Settings.redis_secondary.port)
                  RedisDuplicator.new(secondary_redis, REDIS_CONFIG[:redis])
                else
                  Redis.new(REDIS_CONFIG[:redis])
                end
