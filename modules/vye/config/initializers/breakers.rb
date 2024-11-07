# frozen_string_literal: true

require 'common/client/configuration/base'
require 'common/client/configuration/rest'
require 'breakers/statsd_plugin'

# Not sure if any or all of these are needed
require 'dgib/claimant_lookup/configuration'
require 'dgib/claimant_status/configuration'
require 'dgib/verification_record/configuration'
require 'dgib/verify_claimant/configuration'

Rails.application.reloader.to_prepare do
  redis_namespace = Redis::Namespace.new('breakers', redis: $redis)

  services = [
    Vye::DGIB::Configuration.instance.breakers_service
  ]

  plugin = Breakers::StatsdPlugin.new

  client = Breakers::Client.new(
    redis_connection: redis_namespace,
    services:,
    logger: Rails.logger,
    plugins: [plugin]
  )

  # No need to prefix it when using the namespace
  Breakers.redis_prefix = ''
  Breakers.client = client
  Breakers.disabled = true if Settings.breakers_disabled
end
