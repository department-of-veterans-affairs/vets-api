# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission do
    form_type { '21-4142' }

    trait :pending do
      benefits_intake_uuid { '6d8433c1-cd55-4c24-affd-f592287a7572' }

      form_submission_attempts { create_list(:form_submission_attempt, 1, :pending) }
    end

    trait :success do
      form_submission_attempts { create_list(:form_submission_attempt, 1, :success) }
    end

    trait :failure do
      form_submission_attempts { create_list(:form_submission_attempt, 1, :failure) }
    end

    trait :stale do
      form_submission_attempts { create_list(:form_submission_attempt, 1, :stale) }
    end
  end
end
