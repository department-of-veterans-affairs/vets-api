# frozen_string_literal: true

module Sidekiq
  class JobMetadataMiddleware
    def call(worker, job, _queue)
      return unless worker.is_a?(Sidekiq::JobMetadata)

      worker.instance_variable_set(:@job_metadata, job)
      yield
    end
  end
end
