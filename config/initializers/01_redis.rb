# frozen_string_literal: true

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config

$redis = Redis.new(REDIS_CONFIG[:redis].to_hash)

Redis.exists_returns_integer = true
