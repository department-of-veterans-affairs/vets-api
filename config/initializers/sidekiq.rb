# frozen_string_literal: true

Sidekiq::Enterprise.unique! if Rails.env.production?

Sidekiq.configure_server do |config|
  config.redis = REDIS_CONFIG['redis']
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_scheduler.yml', __FILE__))
    Sidekiq::Scheduler.reload_schedule!
  end

  config.server_middleware do |chain|
    chain.add Sidekiq::Instrument::ServerMiddleware
  end

  config.client_middleware do |chain|
    chain.add Sidekiq::Instrument::ClientMiddleware
  end
end

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONFIG['redis']

  config.client_middleware do |chain|
    chain.add Sidekiq::Instrument::ClientMiddleware
  end

  # Remove the default error handler
  config.error_handlers.delete_if { |handler| handler.is_a?(Sidekiq::ExceptionHandler::Logger) }
end
