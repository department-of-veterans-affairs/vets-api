# frozen_string_literal: true

# this is modified from https://github.com/enova/sidekiq-instrument/blob/v0.3.0/lib/sidekiq/instrument/middleware/server.rb
# sidekiq-instrument is no longer supported, so we are implementing that logic ourselves
module SidekiqStatsInstrumentation
  class ServerMiddleware
    def call(worker, job, _queue, &)
      queue_name = worker.class.get_sidekiq_options['queue']
      worker_name = worker.class.name.gsub('::', '_')
      StatsD.increment "shared.sidekiq.#{queue_name}.#{worker_name}.dequeue"
      source = job['source']
      RequestStore.store['additional_request_attributes'] ||= { 'source' => source } if source
      StatsD.measure("shared.sidekiq.#{queue_name}.#{worker_name}.runtime", &)
    rescue => e
      StatsD.increment("shared.sidekiq.#{queue_name}.#{worker_name}.error")
      raise e
    ensure
      ::RequestStore.clear!
    end
  end
end
