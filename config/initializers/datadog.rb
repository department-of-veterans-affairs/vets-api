# frozen_string_literal: true

require 'datadog/appsec'

envs = %w[development staging sandbox production]

Datadog.configure do |c|
  if envs.include? Settings.vsp_environment
    # Namespace our app
    c.service = 'vets-api'
    c.env = Settings.vsp_environment unless ENV['DD_ENV']
    c.version = AppInfo::GIT_REVISION unless ENV['DD_VERSION']
    unless ENV['DD_TAGS']
      c.tags = {
        'kube_deployment' => ENV['KUBE_DEPLOYMENT'].presence,
        'pod_name' => ENV['POD_NAME'].presence
      }
    end

    # Enable instruments
    c.tracing.instrument :rails
    c.tracing.instrument :sidekiq, service_name: 'vets-api-sidekiq'
    c.tracing.instrument :active_support, cache_service: 'vets-api-cache'
    c.tracing.instrument :action_pack, service_name: 'vets-api-controllers'
    c.tracing.instrument :active_record, service_name: 'vets-api-db'
    c.tracing.instrument :redis, service_name: 'vets-api-redis'
    c.tracing.instrument :pg, service_name: 'vets-api-pg'
    c.tracing.instrument :http, service_name: 'vets-api-net-http'

    # Enable profiling
    c.profiling.enabled = true

    # Enable ASM
    c.appsec.enabled = true
    c.appsec.instrument :rails
  end
end
