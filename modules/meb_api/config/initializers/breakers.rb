# frozen_string_literal: true

require 'common/client/configuration/base'
require 'common/client/configuration/rest'
require 'breakers/statsd_plugin'
require 'dgi/automation/configuration'
require 'dgi/eligibility/configuration'
require 'dgi/status/configuration'
require 'dgi/submission/configuration'
require 'dgi/letters/configuration'

Rails.application.reloader.to_prepare do
  redis_namespace = Redis::Namespace.new('breakers', redis: $redis)

  services = [
    MebApi::DGI::Configuration.instance.breakers_service,
    MebApi::DGI::Letters::Configuration.instance.breakers_service
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
