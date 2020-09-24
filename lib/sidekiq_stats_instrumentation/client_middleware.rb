# frozen_string_literal: true

# this is modified from https://github.com/enova/sidekiq-instrument/blob/v0.3.0/lib/sidekiq/instrument/middleware/client.rb
# sidekiq-instrument is no longer supported, so we are implementing that logic ourselves
module SidekiqStatsInstrumentation
  class ClientMiddleware
    def call(worker_class, _job, _queue, _redis_pool)
      klass = Object.const_get(worker_class)
      queue_name = klass.get_sidekiq_options['queue']
      worker_name = klass.name.gsub('::', '_')
      StatsD.increment "shared.sidekiq.#{queue_name}.#{worker_name}.enqueue"

      yield
    end
  end
end
