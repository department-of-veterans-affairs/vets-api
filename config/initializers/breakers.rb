# frozen_string_literal: true
require 'rx/configuration'
require 'sm/configuration'

# Read the redis config, create a connection and a namespace for breakers
redis_config = Rails.application.config_for(:redis).freeze
redis = Redis.new(redis_config['redis'])
redis_namespace = Redis::Namespace.new('breakers', redis: redis)

services = [
  Rx::Configuration.instance.breakers_service,
  SM::Configuration.instance.breakers_service
]

client = Breakers::Client.new(
  redis_connection: redis_namespace,
  services: services,
  logger: Rails.logger
)

# No need to prefix it when using the namespace
Breakers.redis_prefix = ''
Breakers.client = client
