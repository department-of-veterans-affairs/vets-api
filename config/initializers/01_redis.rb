# frozen_string_literal: true

# environment specific valkey host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Valkey based on environment specific config

$redis =
  if Rails.env.test?
    require 'mock_redis'
    MockRedis.new(url: REDIS_CONFIG[:redis][:url])
  else
    Redis.new(REDIS_CONFIG[:redis].to_h)
  end
