# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission_attempt do
    form_submission

    benefits_intake_uuid { SecureRandom.uuid }

    trait :pending do
      created_at { Time.zone.now }
      aasm_state { 'pending' }
    end

    trait :success do
      aasm_state { 'success' }
    end

    trait :vbms do
      aasm_state { 'vbms' }
    end

    trait :failure do
      aasm_state { 'failure' }
    end

    trait :stale do
      created_at { 99.days.ago }
      aasm_state { 'pending' }
    end
  end
end
