# frozen_string_literal: true

module Sidekiq
  class JobMetadataMiddleware
    def call(job_instance, job_payload, _queue)
      return unless job_instance.is_a?(Sidekiq::JobMetadata)

      job_instance.job_metadata = job_payload
      yield
    end
  end
end
