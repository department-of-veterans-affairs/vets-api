# frozen_string_literal: true

envs = %w[development staging sandbox production]

Datadog.configure do |c|
  c.use :sidekiq
  c.use :rails
  c.service = 'vets-api'
  c.env = Settings.vsp_environment + '-k8s'
  c.tracer.enabled = envs.include? Settings.vsp_environment
  c.tracer hostname: 'datadog-agent',
           port: 8126
end
