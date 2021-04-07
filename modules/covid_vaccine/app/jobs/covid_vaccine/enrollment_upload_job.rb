# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ScheduledBatchJob
    include Sidekiq::Worker
    include SentryLogging

    def perform(batch_id)
      records = CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id: batch_id)
      csv_generator = ExpandedRegistrationCsvGenerator.new(records)
      filename = generated_file_name(batch_id, records.length)
      uploader = CovidVaccine::V0::EnrollmentUploadService.new(csv_generator.io, filename)
      uploader.upload
      update_state_to_pending!
    rescue => e
      log_exception_to_sentry(
        e,
        { code: e.try(:code) },
        { external_service: 'EnrollmentServiceSFTP' }
      )
      raise
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      raise ex
    end
  end

  # rubocop:disable Rails/SkipsModelValidations
  def update_state_to_pending!
    CovidVaccine::V0::ExpandedRegistrationSubmission
      .where(batch_id: batch_id).update_all(state: 'enrollment_pending')
  end
  # rubocop:enable Rails/SkipsModelValidations

  def generated_file_name(batch_id, record_count)
    "DHS_load_#{batch_id}_SLA_#{record_count}_records.txt"
  end
end
