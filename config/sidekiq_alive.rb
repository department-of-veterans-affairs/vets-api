SidekiqAlive.setup do |config|
  # use the POD_NAME environment variable to set the queue name
  config.queue_name = ENV['POD_NAME'] || 'sidekiq_alive_default_queue'
end