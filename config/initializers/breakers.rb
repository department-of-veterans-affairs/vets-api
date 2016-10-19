# frozen_string_literal: true
require 'rx/configuration'

# Read the redis config, create a connection and a namespace for breakers
redis_config = Rails.application.config_for(:redis).freeze
redis = Redis.new(redis_config['redis'])
redis_namespace = Redis::Namespace.new('breakers', redis: redis)

# The Rx::Configuration class contains the host and path for Rx requests.
# Create a matcher proc that returns true for POST requests to that host and path.
rx_path = URI.parse(Rx::Configuration.instance.base_path).path
rx_host = URI.parse(Rx::Configuration.instance.base_path).host
rx_matcher = proc do |request_env|
  request_env.method == :post &&
    request_env.url.host == rx_host &&
    request_env.url.path =~ /^#{rx_path}/
end

# And then create the Breakers service and client
BREAKERS_RX_SERVICE = Breakers::Service.new(
  name: 'Rx',
  request_matcher: rx_matcher
)

client = Breakers::Client.new(
  redis_connection: redis_namespace,
  services: [BREAKERS_RX_SERVICE],
  logger: Rails.logger
)

# No need to prefix it when using the namespace
Breakers.redis_prefix = ''
Breakers.client = client
