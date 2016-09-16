# frozen_string_literal: true
FactoryGirl.define do
  factory :triage_team do
    skip_create

    relation_type 'PATIENT'
    sequence :triage_team_id do |n|
      n
    end

    sequence :name do |n|
      "Triage Group for patient #{n}"
    end
  end
end
