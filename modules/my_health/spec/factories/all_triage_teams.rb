# frozen_string_literal: true

FactoryBot.define do
  factory :all_triage_team, class: 'AllTriageTeams' do
    station_number { '989' }
    blocked_status { false }
    relationship_type { 'PATIENT' }
    preferred_team { false }
    sequence :triage_team_id do |n|
      n
    end

    sequence :name do |n|
      "Triage Group for patient #{n}"
    end
  end
end
