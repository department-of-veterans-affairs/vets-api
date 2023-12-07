# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission_attempt do
    form_submission

    trait :pending do
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
  end
end
