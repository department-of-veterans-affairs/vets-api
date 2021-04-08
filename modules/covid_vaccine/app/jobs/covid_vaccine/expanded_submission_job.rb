# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class ExpandedSubmissionJob
    include Sidekiq::Worker
    include SentryLogging

    def perform(record_id, user_type)
      partial = CovidVaccine::V0::ExpandedRegistrationSubmission.find(record_id)
      CovidVaccine::V0::ExpandedRegistrationService.new.register(partial, user_type)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      raise ex
    end
  end
end
