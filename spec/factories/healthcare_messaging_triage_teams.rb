FactoryGirl.define do
  factory :triage_team, class: VAHealthcareMessaging::TriageTeam do
    relation_type "PATIENT"

    sequence :triage_team_id do |n|
      n
    end

    sequence :name do |n|
      "Triage Group for patient #{n}"
    end
  end
end
