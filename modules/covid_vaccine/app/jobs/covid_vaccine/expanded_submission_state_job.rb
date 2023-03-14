# frozen_string_literal: true

module CovidVaccine
  class ExpandedSubmissionStateJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: false

    def perform
      Rails.logger.info('Covid_Vaccine Expanded_Submission_State_Job Start')
      total_submissions = CovidVaccine::V0::ExpandedRegistrationSubmission.count

      state_data = get_state_data.merge!({ total_count_of_submissions: total_submissions })
      difference = total_submissions - state_data[:total_count_of_states]
      state_data.merge!({ discrepancy_count: difference })

      Rails.logger.info("#{self.class.name}: Count of states", **state_data)
    rescue => e
      handle_errors(e)
    end

    def get_state_data
      states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
      state_data = {}
      state_data_total_count = 0
      states.each do |k, v|
        state_data.merge!({ "#{k}": v }) unless k.nil?
        state_data_total_count += v unless k.nil?
      end
      state_data.merge!({ total_count_of_states: state_data_total_count })
      state_data
    end

    def handle_errors(ex)
      Rails.logger.error("Covid_Vaccine Expanded_Submission_State_Job Failed: #{ex}")
    end
  end
end
