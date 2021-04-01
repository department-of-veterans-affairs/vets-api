# frozen_string_literal: true

namespace :covid_vaccine do
  desc 'Display summary of submissions by state'
  task state_summary: :environment do |_task|
    states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
    states.each do |k, v|
      puts "#{k || 'nil'}: #{v}"
    end
  end

  desc 'Trigger eligibility processing of received submissions'
  task process_eligibility: :environment do |_task|
    # Capture submissions from initial launch before state machine was integrated that have a nil state
    CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: nil).find_each do |submission|
      CovidVaccine::ExpandedEligibilityJob.perform_async(submission.id)
    end

    CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: 'received').find_each do |submission|
      CovidVaccine::ExpandedEligibilityJob.perform_async(submission.id)
    end
  end
end
