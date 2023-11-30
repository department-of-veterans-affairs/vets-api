# frozen_string_literal: true

# Sidekiq middleware that integrates Datadog tracing.
# It sets a custom service tag for the active span at the beginning
# of the job execution and ensures it is cleared afterwards.
#
# @example Adding to Sidekiq middleware chain
#   Sidekiq.configure_server do |config|
#     config.server_middleware do |chain|
#       chain.add Sidekiq::TracingMiddleware
#     end
#   end
module Sidekiq
  class TracingMiddleware
    # Called by Sidekiq to perform the job.
    # It sets the service tag on the active Datadog span based on the worker's defined tag.
    # In case of an error during this process, the error is logged and re-raised so that
    # the job is retried by Sidekiq if applicable..
    #
    # @param worker [Object] The worker instance executing the job.
    # @param _job [Hash] The job data (unused in method but required for middleware interface).
    # @param _queue [String] The queue name from which the job is pulled (unused in method).
    # @yield The block to perform the actual job.
    # @return [void]
    def call(worker, _job, _queue)
      service_tag = worker.respond_to?(:trace_service_tag) ? worker.trace_service_tag : 'vets-api-sidekiq'

      Datadog::Tracing.trace('sidekiq.job', service: service_tag,
                                            resource: worker.class.name,
                                            span_type: 'worker') do |_span|
        yield
      end
    rescue => e
      Rails.logger.error("Error setting service tag in Sidekiq::TracingMiddleware for #{worker.class.name}")
      raise e
    end
  end
end
