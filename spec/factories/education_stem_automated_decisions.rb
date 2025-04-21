# frozen_string_literal: true

FactoryBot.define do
  factory :education_stem_automated_decision do
    transient do
      user { create(:user, :loa3, :with_terms_of_use_agreement, uuid: SecureRandom.uuid) }
    end
    automated_decision_state { EducationStemAutomatedDecision::INIT }
    user_uuid { user.uuid }
    poa { false }
    user_account { user.user_account }

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
