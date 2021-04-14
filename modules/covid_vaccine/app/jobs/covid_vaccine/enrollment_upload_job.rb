# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class EnrollmentUploadJob
    include Sidekiq::Worker
    include SentryLogging

    STATSD_ERROR_NAME = 'worker.covid_vaccine_enrollment_upload.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_enrollment_upload.success'

    def perform(batch_id)
      Rails.logger.info('Covid_Vaccine Enrollment_Upload: Start', batch_id: batch_id)
      resolve_facilities(batch_id)
      upload(batch_id)
      StatsD.increment(STATSD_SUCCESS_NAME)
    rescue => e
      handle_errors(e, batch_id)
    end

    private

    def resolve_facilities(batch_id)
      update_count = 0
      CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id: batch_id).find_each do |submission|
        resolver = CovidVaccine::V0::FacilityResolver.new
        mapped_facility = resolver.resolve(submission)
        submission.eligibility_info = { preferred_facility: mapped_facility }
        submission.save!
        update_count += 1
      end

      Rails.logger.info('Covid_Vaccine Enrollment_Upload: Updated mapped facility info', batch_id: batch_id,
                                                                                         record_count: update_count)
    end

    def upload(batch_id)
      processor = CovidVaccine::V0::EnrollmentProcessor.new(batch_id)
      record_count = processor.process_and_upload!

      Rails.logger.info('Covid_Vaccine Enrollment_Upload: Success', batch_id: batch_id, record_count: record_count)
    end

    def handle_errors(ex, batch_id)
      Rails.logger.error('Covid_Vaccine Enrollment_Upload: Failed', batch_id: batch_id)
      log_exception_to_sentry(ex)
      StatsD.increment(STATSD_ERROR_NAME)
      raise ex
    end
  end
end
