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
    chain.add Sidekiq::ErrorTag
  end

  config.client_middleware do |chain|
    chain.add Sidekiq::Instrument::ClientMiddleware
  end

  SemanticLogger.on_log do |log|
    Raven.tags_context[:request_id].tap do |request_id|
      next if request_id.blank?
      log.named_tags[:request_id] = request_id
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONFIG['redis']

  config.client_middleware do |chain|
    chain.add Sidekiq::Instrument::ClientMiddleware
    chain.add Sidekiq::SetRequestId
  end

  # Remove the default error handler
  config.error_handlers.delete_if { |handler| handler.is_a?(Sidekiq::ExceptionHandler::Logger) }
end
