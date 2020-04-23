# frozen_string_literal: true

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config
# This is raising deprecation warnings because a ActiveSupport::OrderedOptions won't support string keys in Rails 6.1
Redis.current = Redis.new(REDIS_CONFIG[:redis])
