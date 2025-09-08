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

    # VFF Form traits
    # rubocop:disable Naming/VariableNumber
    trait :vff_21966 do
      form_type { '21-0966' }
      form_data do
        {
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'ssn' => '123456789',
          'email' => 'john.doe@example.com',
          'phone' => '555-123-4567',
          'preparerIdentification' => 'VETERAN',
          'intentTypes' => ['disability'],
          'form_name' => '21-0966'
        }.to_json
      end
    end

    trait :vff_214142 do # rubocop:disable Naming/VariableNumber
      form_type { '21-4142' }
      form_data do
        {
          'full_name' => { 'first' => 'Jane', 'last' => 'Smith' },
          'ssn' => '987654321',
          'email' => 'jane.smith@example.com',
          'phone' => '555-987-6543',
          'form_name' => '21-4142'
        }.to_json
      end
    end

    trait :vff_2110210 do # rubocop:disable Naming/VariableNumber
      form_type { '21-10210' }
      form_data do
        {
          'full_name' => { 'first' => 'Bob', 'last' => 'Johnson' },
          'ssn' => '456789123',
          'email' => 'bob.johnson@example.com',
          'form_name' => '21-10210'
        }.to_json
      end
    end

    trait :vff_21972 do # rubocop:disable Naming/VariableNumber
      form_type { '21-0972' }
      form_data do
        {
          'full_name' => { 'first' => 'Alice', 'last' => 'Williams' },
          'ssn' => '321654987',
          'email' => 'alice.williams@example.com',
          'form_name' => '21-0972'
        }.to_json
      end
    end

    trait :vff_21p847 do
      form_type { '21P-0847' }
      form_data do
        {
          'full_name' => { 'first' => 'Charlie', 'last' => 'Brown' },
          'ssn' => '654321789',
          'email' => 'charlie.brown@example.com',
          'form_name' => '21P-0847'
        }.to_json
      end
    end

    trait :vff_2010206 do # rubocop:disable Naming/VariableNumber
      form_type { '20-10206' }
      form_data do
        {
          'full_name' => { 'first' => 'Diana', 'last' => 'Davis' },
          'ssn' => '789123456',
          'email' => 'diana.davis@example.com',
          'form_name' => '20-10206'
        }.to_json
      end
    end

    trait :vff_2010207 do # rubocop:disable Naming/VariableNumber
      form_type { '20-10207' }
      form_data do
        {
          'full_name' => { 'first' => 'Edward', 'last' => 'Miller' },
          'ssn' => '147258369',
          'email' => 'edward.miller@example.com',
          'form_name' => '20-10207'
        }.to_json
      end
    end

    trait :vff_21845 do # rubocop:disable Naming/VariableNumber
      form_type { '21-0845' }
      form_data do
        {
          'full_name' => { 'first' => 'Fiona', 'last' => 'Wilson' },
          'ssn' => '963852741',
          'email' => 'fiona.wilson@example.com',
          'form_name' => '21-0845'
        }.to_json
      end
    end
    # rubocop:enable Naming/VariableNumber

    # Generic VFF trait that randomly selects a VFF form type
    trait :vff_form do
      vff_forms = %w[vff_21966 vff_214142 vff_2110210 vff_21972 vff_21p847 vff_2010206 vff_2010207
                     vff_21845]
      transient do
        vff_form_type { vff_forms.sample }
      end

      after(:build) do |form_submission, evaluator|
        form_submission.send(evaluator.vff_form_type)
      end
    end
  end
end
