# frozen_string_literal: true

require 'sentry_logging'

module CovidVaccine
  class SubmissionJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options expires_in: 1.day, retry: 10

    def perform(record_id, user_type)
      partial = CovidVaccine::V0::RegistrationSubmission.find(record_id)
      CovidVaccine::V0::Services.new.register(partial, user_type)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      raise ex
    end
  end
end
