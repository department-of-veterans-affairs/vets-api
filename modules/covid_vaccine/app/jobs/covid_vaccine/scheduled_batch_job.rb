# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ScheduledBatchJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: false

    STATSD_ERROR_NAME = 'worker.covid_vaccine_schedule_batch.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_schedule_batch.success'

    def perform
      Rails.logger.info('Covid_Vaccine Scheduled_Batch: Start')

      batch_id = CovidVaccine::V0::EnrollmentProcessor.batch_records!
      Rails.logger.info('Covid_Vaccine Scheduled_Batch: Batch_Created', batch_id:)

      success_details = { batch_id: }
      if enrollment_upload_enabled?
        jid = CovidVaccine::EnrollmentUploadJob.perform_async(batch_id)
        success_details.merge!(enrollment_upload_job_id: jid)
      end

      Rails.logger.info('Covid_Vaccine Scheduled_Batch: Success', success_details)
      StatsD.increment(STATSD_SUCCESS_NAME)
    rescue => e
      handle_errors(e)
    end

    private

    def enrollment_upload_enabled?
      Settings.dig('covid_vaccine', 'enrollment_service', 'job_enabled')
    end

    def handle_errors(ex)
      Rails.logger.error('Covid_Vaccine Scheduled_Batch: Failed')
      log_exception_to_sentry(ex)
      StatsD.increment(STATSD_ERROR_NAME)
      raise ex
    end
  end
end
