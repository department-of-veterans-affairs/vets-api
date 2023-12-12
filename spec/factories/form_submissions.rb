# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission do
    form_type { '21-4142' }

    trait :pending do
      form_submission_attempts { create_list(:form_submission_attempt, 1, :pending) }
    end
  end
end
