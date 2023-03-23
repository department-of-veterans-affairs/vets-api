# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class EnrollmentUploadJob
    include Sidekiq::Worker
    include SentryLogging

    STATSD_ERROR_NAME = 'worker.covid_vaccine_enrollment_upload.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_enrollment_upload.success'

    def perform(batch_id)
      Rails.logger.info('Covid_Vaccine Enrollment_Upload: Start', batch_id:)

      processor = CovidVaccine::V0::EnrollmentProcessor.new(batch_id)
      record_count = processor.process_and_upload!

      Rails.logger.info('Covid_Vaccine Enrollment_Upload: Success', batch_id:, record_count:)
      StatsD.increment(STATSD_SUCCESS_NAME)
    rescue => e
      handle_errors(e, batch_id)
    end

    def handle_errors(ex, batch_id)
      Rails.logger.error('Covid_Vaccine Enrollment_Upload: Failed', batch_id:)
      log_exception_to_sentry(ex)
      StatsD.increment(STATSD_ERROR_NAME)
      raise ex
    end
  end
end
