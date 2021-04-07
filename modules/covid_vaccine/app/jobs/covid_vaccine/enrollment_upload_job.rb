# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ScheduledBatchJob
    include Sidekiq::Worker
    include SentryLogging

    def perform(batch_id)
      processor = CovidVaccine::V0::EnrollmentProcessor.new(batch_id)
      record_count = processor.process_and_upload!
      audit_log(batch_id, record_count)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      raise ex
    end
  end

  def audit_log(batch_id, record_count)
    log_attrs = {
      batch_id: batch_id,
      records: record_count
    }
    Rails.logger.info('Covid_Vaccine Enrollment_Upload', log_attrs.to_json)
  end
end
