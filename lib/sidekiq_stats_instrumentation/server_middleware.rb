# frozen_string_literal: true

# this is modified from https://github.com/enova/sidekiq-instrument/blob/v0.3.0/lib/sidekiq/instrument/middleware/server.rb
# sidekiq-instrument is no longer supported, so we are implementing that logic ourselves
module SidekiqStatsInstrumentation
  class ServerMiddleware
    def call(worker, _job, _queue, &block)
      queue_name = worker.class.get_sidekiq_options['queue']
      worker_name = worker.class.name.gsub('::', '_')
      StatsD.increment "shared.sidekiq.#{queue_name}.#{worker_name}.dequeue"

      StatsD.measure("shared.sidekiq.#{queue_name}.#{worker_name}.runtime", &block)
    rescue => e
      StatsD.increment("shared.sidekiq.#{queue_name}.#{worker_name}.error")
      raise e
    end
  end
end
