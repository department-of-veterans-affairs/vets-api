# frozen_string_literal: true

FactoryBot.define do
  factory :bgs_submission, class: 'BGS::Submission' do
    form_id { 'TEST' }
    latest_status { 'pending' }
    association :saved_claim, factory: :add_remove_dependents_claim
    reference_data do
      {
        'icn' => '1234567890V123456',
        'ssn' => '123456789',
        'participant_id' => '12345678',
        'file_number' => '987654321',
        'proc_id' => 'ABC123DEF456'
      }
    end

    trait :pending do
      latest_status { 'pending' }
      submission_attempts { build_list(:bgs_submission_attempt, 1, :pending) }
    end

    trait :submitted do
      latest_status { 'submitted' }
      submission_attempts { build_list(:bgs_submission_attempt, 1, :submitted) }
    end

    trait :failure do
      latest_status { 'failure' }
      submission_attempts { build_list(:bgs_submission_attempt, 1, :failure) }
    end

    trait :with_claim_id do
      bgs_claim_id { '12345678' }
    end

    trait :with_686c_form do
      form_id { '21-686C' }
    end

    trait :with_674_form do
      form_id { '21-674' }
    end

    trait :with_multiple_attempts do
      after(:create) do |submission|
        create_list(:bgs_submission_attempt, 3, submission:)
      end
    end

    trait :with_pending_and_submitted_attempts do
      after(:create) do |submission|
        create(:bgs_submission_attempt, :pending, submission:, created_at: 2.hours.ago)
        create(:bgs_submission_attempt, :submitted, submission:, created_at: 1.hour.ago)
      end
    end

    trait :with_all_attempt_statuses do
      after(:create) do |submission|
        create(:bgs_submission_attempt, :pending, submission:, created_at: 3.hours.ago)
        create(:bgs_submission_attempt, :submitted, submission:, created_at: 2.hours.ago)
        create(:bgs_submission_attempt, :failure, submission:, created_at: 1.hour.ago)
      end
    end
  end
end
