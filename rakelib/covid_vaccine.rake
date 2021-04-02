# frozen_string_literal: true

namespace :covid_vaccine do
  desc 'Display summary of submissions by state'
  task state_summary: :environment do |_task|
    states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
    states.each do |k, v|
      puts "#{k || 'nil'}: #{v}"
    end
  end
end
