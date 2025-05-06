# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission do
    form_type { '21-4142' }
    form_data do
      {
        'id_number' => { 'ssn' => '444444444' },
        'postal_code' => '12345',
        'full_name' => { 'first' => 'First', 'last' => 'Last' },
        'email' => 'a@b.com',
        'form_name' => 'Form Name'
      }.to_json
    end

    trait :pending do
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
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: '4b846069-e496-4f83-8587-42b570f24483')
      end
      created_at { '2024-03-08' }
    end

    trait :with_form210845 do
      user_account_id { '' }
      form_type { '21-0845' }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: 'd0c6cea6-9885-4e2f-8e0c-708d5933833a')
      end
      created_at { '2024-03-12' }
    end

    trait :with_form_blocked do
      user_account_id { '' }
      form_type { 'NOT-WHITELISTED' }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: '84dd8902-0744-4b1a-ab3f-6b4ec3e5dd3c')
      end
      created_at { '2024-04-12' }
    end
  end
end
