# frozen_string_literal: true

require 'sidekiq_stats_instrumentation/client_middleware'
require 'sidekiq_stats_instrumentation/server_middleware'
require 'sidekiq/retry_monitoring'
require 'sidekiq/error_tag'
require 'sidekiq/semantic_logging'
require 'sidekiq/set_request_id'
require 'sidekiq/set_request_attributes'

Rails.application.reloader.to_prepare do
  Sidekiq::Enterprise.unique! if Rails.env.production?

  Sidekiq.configure_server do |config|
    config.redis = REDIS_CONFIG[:sidekiq]
    # super_fetch! is only available in sidekiq-pro and will cause
    #   "undefined method `super_fetch!'"
    # for those using regular sidekiq
    config.super_fetch! if defined?(Sidekiq::Pro)

    config.on(:startup) do
      Sidekiq.schedule = YAML.safe_load(
        ERB.new(File.read(File.expand_path('../sidekiq_scheduler.yml', __dir__))).result
      )
      Sidekiq::Scheduler.reload_schedule!
    end

    config.server_middleware do |chain|
      chain.add Sidekiq::SemanticLogging
      chain.add SidekiqStatsInstrumentation::ServerMiddleware
      chain.add Sidekiq::RetryMonitoring
      chain.add Sidekiq::ErrorTag
    end

    config.client_middleware do |chain|
      chain.add SidekiqStatsInstrumentation::ClientMiddleware
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = REDIS_CONFIG[:sidekiq]

    config.client_middleware do |chain|
      chain.add SidekiqStatsInstrumentation::ClientMiddleware
      chain.add Sidekiq::SetRequestId
      chain.add Sidekiq::SetRequestAttributes
    end

    # Remove the default error handler
    config.error_handlers.delete_if { |handler| handler.is_a?(Sidekiq::ExceptionHandler::Logger) }
  end
end
