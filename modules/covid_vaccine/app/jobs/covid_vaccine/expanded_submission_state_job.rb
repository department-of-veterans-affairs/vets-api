# frozen_string_literal: true

module CovidVaccine
  class ExpandedSubmissionStateJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: false

    def perform
      Rails.logger.info('Covid_Vaccine Expanded_Submission_State_Job Start')
      states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
      state_data = {}
      states.each do |k, v|
        state_data.merge!({ "#{k}": v }) unless k.nil?
      end
      Rails.logger.info("#{self.class.name}: Count of states", state_data)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(_ex)
      Rails.logger.error('Covid_Vaccine Expanded_Submission_State_Job Failed')
    end
  end
end
