# frozen_string_literal: true

worker_count = Integer(ENV.fetch('WEB_CONCURRENCY', 0))
workers worker_count

threads_count_min = Integer(ENV.fetch('RAILS_MIN_THREADS', 5))
threads_count_max = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
threads(threads_count_min, threads_count_max)

# used for a healthcheck endpoint that will not consume one of the threads
activate_control_app 'tcp://0.0.0.0:9293', { no_token: true }

# Only define worker callbacks when actually using workers (cluster mode)
if worker_count > 0
  on_worker_boot do
    SemanticLogger.reopen
    ActiveRecord::Base.establish_connection
  end

  on_worker_shutdown do
    require 'kafka/producer_manager'
    Kafka::ProducerManager.instance.producer&.close
  end
end
