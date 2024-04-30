# frozen_string_literal: true

SidekiqAlive.setup do |config|
  # use the POD_NAME environment variable to set the queue name
  config.queue_prefix = "#{ENV.fetch('POD_NAME', 'sidekiq_alive_default_queue')}_sidekiq_alive"

  config.shutdown_callback = proc do
    queue_name = "#{config.queue_prefix}-#{SidekiqAlive.hostname}"
    Sidekiq.logger.info "Looking for queue: #{queue_name}"

    queue = Sidekiq::Queue.all.find { |q| q.name == queue_name }

    if queue
      Sidekiq.logger.info "Found queue: #{queue_name}, clearing..."
      queue.clear
    else
      Sidekiq.logger.warn "Could not find queue: #{queue_name}"
    end
  end
end
