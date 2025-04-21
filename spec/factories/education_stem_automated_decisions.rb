# frozen_string_literal: true

FactoryBot.define do
  factory :education_stem_automated_decision do
    transient do
      user do
        create(:user, :loa3, :with_terms_of_use_agreement, uuid: SecureRandom.uuid, idme_uuid: SecureRandom.uuid)
      end
    end
    automated_decision_state { EducationStemAutomatedDecision::INIT }
    poa { false }
    user_uuid { user.uuid }
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
