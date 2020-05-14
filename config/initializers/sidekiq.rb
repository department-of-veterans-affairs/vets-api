# frozen_string_literal: true

Sidekiq::Enterprise.unique! if Rails.env.production?

# these are modified from https://github.com/enova/sidekiq-instrument/tree/v0.3.0/lib/sidekiq/instrument/middleware
# sidekiq-instrument is no longer supported, so we are building in that logic
module SharedSidekiqInstrumentation
  class ClientMiddleware
    def call(worker_class, job, queue, redis_pool)
      klass = Object.const_get(worker_class)
      # worker = klass.new
      queue_name = klass.get_sidekiq_options['queue']
      worker_name = klass.name.gsub('::', '_')
      StatsD.increment "shared.sidekiq.#{queue_name}.#{worker_name}.enqueue"

      yield
    end
  end

  class ServerMiddleware
    def call(worker, job, queue, &block)
      queue_name = worker.class.get_sidekiq_options['queue']
      worker_name = worker.class.name.gsub('::', '_')
      StatsD.increment "shared.sidekiq.#{queue_name}.#{worker_name}.dequeue"

      StatsD.measure("shared.sidekiq.#{queue_name}.#{worker_name}.runtime", &block)
    rescue StandardError => e
      StatsD.increment("shared.sidekiq.#{queue_name}.#{worker_name}.error")
      raise e
    end
  end
end

Sidekiq.configure_server do |config|
  config.redis = REDIS_CONFIG[:redis]
  # super_fetch! is only available in sidekiq-pro and will cause
  #   "undefined method `super_fetch!'"
  # for those using regular sidekiq
  config.super_fetch! if defined?(Sidekiq::Pro)

  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../sidekiq_scheduler.yml', __dir__))
    Sidekiq::Scheduler.reload_schedule!
  end

  config.server_middleware do |chain|
    chain.add Sidekiq::SemanticLogging
    chain.add SharedSidekiqInstrumentation::ServerMiddleware
    chain.add Sidekiq::ErrorTag
  end

  config.client_middleware do |chain|
    chain.add SharedSidekiqInstrumentation::ClientMiddleware
  end
end

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONFIG[:redis]

  config.client_middleware do |chain|
    chain.add SharedSidekiqInstrumentation::ClientMiddleware
    chain.add Sidekiq::SetRequestId
    chain.add Sidekiq::SetRequestAttributes
  end

  # Remove the default error handler
  config.error_handlers.delete_if { |handler| handler.is_a?(Sidekiq::ExceptionHandler::Logger) }
end
