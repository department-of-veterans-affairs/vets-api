# frozen_string_literal: true

module Sidekiq
  class SetCurrentRetry
    def call(worker, job, _queue)
      if worker.respond_to?(:current_retry=)
        # value of job['retry_count'] follows the progression: nil, 0, 1, 2, 3, ...
        worker.current_retry = job['retry_count'].present? ? (job['retry_count'].to_i + 1) : nil
      end

      yield
    end
  end
end
