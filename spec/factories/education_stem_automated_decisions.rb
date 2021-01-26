# frozen_string_literal: true

FactoryBot.define do
  factory :education_stem_automated_decision do
    automated_decision_state { 'init' }
    user_uuid { SecureRandom.uuid }
    poa { false }

    trait :with_poa do
      poa { true }
    end

    trait :denied do
      automated_decision_state { 'denied' }
    end

    trait :processed do
      automated_decision_state { 'processed' }
    end
  end
end
