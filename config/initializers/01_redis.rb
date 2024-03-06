# frozen_string_literal: true

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config

$redis = Redis.new(REDIS_CONFIG[:redis].to_hash)
# if Rails.env.test?
#   require 'testcontainers/redis'
#   container = Testcontainers::RedisContainer.new("redis:6.2-alpine")
#   container.start
#   puts "starting Test Redis Container: #{container.first_mapped_port}"
#   Redis.new(url: container.redis_url)
# else
#   Redis.new(REDIS_CONFIG[:redis].to_h)
# end
