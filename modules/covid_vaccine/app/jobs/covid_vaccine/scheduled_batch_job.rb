# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ScheduledBatchJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq.options retry: false

    def perform
      batch_id = CovidVaccine::V0::EnrollmentProcessor.batch_records!
      CovidVaccine::EnrollmentUploadJob.perform_async(batch_id)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      raise ex
    end
  end
end
