# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ExpandedSubmissionJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: false

    def perform(record_id)
      submission = CovidVaccine::V0::ExpandedRegistrationSubmission.find(record_id)
      CovidVaccine::V0::ExpandedRegistrationService.new.register(submission)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
    end
  end
end
