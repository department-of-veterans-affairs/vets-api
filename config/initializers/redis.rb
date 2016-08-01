# environment specific redis host and port (see: config/redis.yml)
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
# set the current global instance of Redis based on environment specific config
Redis.current = Redis.new(REDIS_CONFIG)

# TODO: These should be handled by model, but some examples are provided here
# specify namespaced redis-stores used in the app
# SESSION_STORE = Redis::Namespace.new("vets-api-session", redis: Redis.current)
# MVI_STORE = Redis::Namespace.new("vets-api-mvi", redis: Redis.current)
