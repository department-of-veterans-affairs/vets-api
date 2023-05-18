# frozen_string_literal: true

SidekiqAlive.setup do |config|
  # use the POD_NAME environment variable to set the queue name
  config.queue_prefix = "#{ENV.fetch('POD_NAME', 'sidekiq_alive_default_queue')}_sidekiq_alive"
  Rails.logger.info "SidekiqAlive initialized with queue_prefix: #{config.queue_prefix}"
end
