# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ScheduledBatchJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq.options retry: false

    # rubocop:disable Rails/SkipsModelValidations
    def perform
      batch_id = Time.now.utc.strftime('%Y%m%d%H%M%S')
      records = CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: 'received', batch_id: nil)
      records.update_all(batch_id: @batch_id)

      CovidVaccine::EnrollmentUploadJob.perform_async(batch_id)
    rescue => e
      handle_errors(e)
    end
    # rubocop:enable Rails/SkipsModelValidations

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      raise ex
    end
  end
end
