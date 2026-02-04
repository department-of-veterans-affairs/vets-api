# frozen_string_literal: true

FactoryBot.define do
  factory :all_triage_team, class: 'AllTriageTeams' do
    station_number { '989' }
    blocked_status { false }
    relation_type { 'PATIENT' }
    preferred_team { false }
    lead_provider_name { 'Dr. John Doe' }
    location_name { 'Main Hospital' }
    team_name { 'Primary Care Team' }
    suggested_name_display { 'Primary Care' }
    health_care_system_name { 'VA Health System' }
    group_type_enum_val { 'Primary' }
    sub_group_type_enum_val { 'General' }
    group_type_patient_display { 'Primary Care' }
    sub_group_type_patient_display { 'General Care' }
    oh_triage_group { false }
    migrating_to_oh { false }
    sequence :triage_team_id do |n|
      n
    end

    sequence :name do |n|
      "Triage Group for patient #{n}"
    end
  end
end
