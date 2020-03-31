# frozen_string_literal: true

# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config
Redis.current = Redis.new(REDIS_CONFIG[:redis]) # This is raising deprecation warnings because we're passing a ActiveSupport::OrderedOptions which won't support string keys in Rails 6.1
