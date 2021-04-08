# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ScheduledBatchJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: false

    def perform
      Rails.logger.info('Covid_Vaccine Scheduled_Batch: Start')

      batch_id = CovidVaccine::V0::EnrollmentProcessor.batch_records!
      Rails.logger.info('Covid_Vaccine Scheduled_Batch: Batch_Created', batch_id: batch_id)

      jid = CovidVaccine::EnrollmentUploadJob.perform_async(batch_id)
      Rails.logger.info('Covid_Vaccine Scheduled_Batch: Success', batch_id: batch_id, enrollment_upload_job_id: jid)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      Rails.logger.error('Covid_Vaccine Scheduled_Batch: Failed')
      log_exception_to_sentry(ex)
      raise ex
    end
  end
end
