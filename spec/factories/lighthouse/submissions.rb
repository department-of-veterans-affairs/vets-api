# frozen_string_literal: true

FactoryBot.define do
  factory :lighthouse_submission, class: 'Lighthouse::Submission' do
    form_id { 'TEST' }
    reference_data do
      {
        'id_number' => { 'ssn' => '444444444' },
        'postal_code' => '12345',
        'full_name' => { 'first' => 'First', 'last' => 'Last' },
        'email' => 'a@b.com',
        'form_name' => 'Form Name'
      }.to_json
    end

    trait :pending do
      submission_attempts { create_list(:lighthouse_submission_attempt, 1, :pending) }
    end

    trait :submitted do
      submission_attempts { create_list(:lighthouse_submission_attempt, 1, :submitted) }
    end

    trait :vbms do
      submission_attempts { create_list(:lighthouse_submission_attempt, 1, :vbms) }
    end

    trait :failure do
      submission_attempts { create_list(:lighthouse_submission_attempt, 1, :failure) }
    end

    trait :stale do
      submission_attempts { create_list(:lighthouse_submission_attempt, 1, :stale) }
    end
  end
end
