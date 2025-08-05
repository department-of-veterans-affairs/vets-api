# frozen_string_literal: true

require 'sidekiq/monitored_worker'
require 'sidekiq/retry_monitoring'

module Sidekiq
  class RetryMonitoring
    def call(worker, params, _queue)
      worker.notify(params) if should_notify?(worker, params)
    rescue => e
      ::Rails.logger.error e
    ensure
      yield
    end

    private

    def should_notify?(worker, job)
      return false unless job['retry_count']

      # retry_count is incremented after all middlewares are called

      worker.is_a?(Sidekiq::MonitoredWorker) &&
        (Integer(job['retry_count']) + 1).in?(worker.retry_limits_for_notification)
    end
  end
end
