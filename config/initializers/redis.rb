# frozen_string_literal: true
class VetsApiRedis < Redis
  class << self
    attr_accessor :other_redis
  end
end

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config
VetsApiRedis.current = Redis.new(REDIS_CONFIG['redis'])

VetsApiRedis.other_redis = Redis.new(host: Settings.redis_secondary.host, port: Settings.redis_secondary.port)