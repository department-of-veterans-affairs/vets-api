# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission do
    form_type { '21-4142' }
    form_data { '{}' }
    benefits_intake_uuid { SecureRandom.uuid }

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

    user_account { create(:user_account) }

    trait :with_form214142 do
      user_account_id { '' }
      form_type { '21-4142' }
      benefits_intake_uuid { 'eff61cbc-f379-421d-977e-d7fd1a06bca3' }
      created_at { '2024-03-08' }
    end

    trait :with_form210845 do
      user_account_id { '' }
      form_type { '21-0845' }
      benefits_intake_uuid { '6d353dee-a0e0-40e3-a25c-9b652247a0d9' }
      created_at { '2024-03-12' }
    end

    trait :with_form_blocked do
      user_account_id { '' }
      form_type { 'NOT-WHITELISTED' }
      benefits_intake_uuid { '84dd8902-0744-4b1a-ab3f-6b4ec3e5dd3c' }
      created_at { '2024-04-12' }
    end
  end
end
