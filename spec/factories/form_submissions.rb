# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission do
    benefits_intake_uuid { SecureRandom.uuid }

    trait :pending do
      form_submission_attempts { create_list(:form_submission_attempt, 1, :pending) }
    end
  end
end
