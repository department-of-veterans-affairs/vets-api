module CovidVaccine
  class ExpandedSubmissionStateJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: false

    def perform
      puts 'Starting state data job'
      states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
      state_data = ''
      states.each do |k, v|
        puts "#{k || 'nil'}: #{v}"
        state_data.merge("#{k || 'nil'}: #{v}")
      end
      puts state_data
      binding.pry
      #   rescue => e
      #     handle_errors(e)
    end

    def handle_errors(ex)
      binding.pry
      Rails.logger.error('Covid_Vaccine Expanded_Submission_State_Job Failed')
    end
  end
end
