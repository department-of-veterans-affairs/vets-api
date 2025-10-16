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
      updated_at { 2.days.ago }
      created_at { 3.days.ago }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: '4b846069-e496-4f83-8587-42b570f24483')
      end
    end

    trait :with_form214140 do
      user_account_id { '' }
      form_type { '21-4140' }
      updated_at { 1.day.ago }
      created_at { 2.days.ago }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: 'a1b2c3d4-e496-4f83-8587-42b570f24483')
      end
    end

    trait :with_form210845 do
      user_account_id { '' }
      form_type { '21-0845' }
      updated_at { 4.days.ago }
      created_at { 5.days.ago }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: 'd0c6cea6-9885-4e2f-8e0c-708d5933833a')
      end
    end

    trait :with_form2010207 do
      user_account_id { '' }
      form_type { '20-10207' }
      updated_at { 89.days.ago }
      created_at { 90.days.ago }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: 'b37dcffa-e96c-4107-9463-9779b98d59d2')
      end
    end

    trait :with_form_blocked do
      user_account_id { '' }
      form_type { 'NOT-WHITELISTED' }
      updated_at { 6.days.ago }
      created_at { 7.days.ago }
      form_submission_attempts do
        create_list(:form_submission_attempt, 1, benefits_intake_uuid: '84dd8902-0744-4b1a-ab3f-6b4ec3e5dd3c')
      end
    end
  end
end
