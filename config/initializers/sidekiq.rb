# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = REDIS_CONFIG['redis']
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_scheduler.yml', __FILE__))
    Sidekiq::Scheduler.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONFIG['redis']
end
