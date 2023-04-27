# frozen_string_literal: true

require 'benchmark'

module Sidekiq::Middleware
  class BenchmarkLoggingMiddleware
    # include Sidekiq::BenchmarkLoggingWorker in your sidekiq job to apply this middleware to it
    def call(worker, _job, _queue, &block)
      if worker.is_a?(Sidekiq::BenchmarkLoggingWorker)
        m = Benchmark.measure(&block)
        data = { real: m.real.round, system: m.stime.round, total: m.total.round, user: m.utime.round }
        Rails.logger.info "Sidekiq job #{worker.class.name} benchmark: #{data.to_json}"
      else
        block.call
      end
    end
  end
end
