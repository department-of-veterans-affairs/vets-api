# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ExpandedScheduledSubmissionJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options(unique_for: 5.minutes, retry: false)

    def perform
      Rails.logger.info('Covid_Vaccine Expanded_Scheduled_Submission: Start')
      #   Sorting by DESC here because currently if a record fails MPI lookup, it remains in state=enrollment_pending,
      #   so starting at the beginning we may never see the new records as only the MPI error records would process
      #   due to limit with anticipated volume and execution every 15 minutes we should be able to process all new
      #   records todo: implement task to find and deal with MPI error records and enrollment_out_of_bounds records
      CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: 'enrollment_pending')
                                                      .order('created_at DESC').limit(1000).map do |submission|
        CovidVaccine::ExpandedSubmissionJob.perform_async(submission.id)
      end
    rescue => e
      handle_errors(e)
    end

    #   the subtask being called only raises an error if the record id is not found in the database,
    def handle_errors(ex)
      Rails.logger.error('Covid_Vaccine Expanded_Scheduled_Submission: Failed')
      log_exception_to_sentry(ex)
      raise ex
    end
  end
end
