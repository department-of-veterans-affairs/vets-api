# frozen_string_literal: true

FactoryBot.define do
  factory :education_stem_automated_decision do
    automated_decision_state { EducationStemAutomatedDecision::INIT }
    user_uuid { SecureRandom.uuid }
    poa { false }

    trait :with_poa do
      poa { true }
    end

    trait :denied do
      remaining_entitlement { 181 }
      automated_decision_state { EducationStemAutomatedDecision::DENIED }
    end

    trait :processed do
      automated_decision_state { EducationStemAutomatedDecision::PROCESSED }
    end
  end
end
