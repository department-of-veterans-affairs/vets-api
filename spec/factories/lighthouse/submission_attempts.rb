# frozen_string_literal: true

FactoryBot.define do
  factory :lighthouse_submission_attempt, class: 'Lighthouse::SubmissionAttempt' do
    submission { create(:lighthouse_submission) }

    benefits_intake_uuid { SecureRandom.uuid }
    created_at { Time.zone.now }

    trait :pending do
      created_at { Time.zone.now }
      status { 'pending' }
    end

    trait :submitted do
      status { 'submitted' }
    end

    trait :vbms do
      status { 'vbms' }
    end

    trait :failure do
      status { 'failure' }
    end

    trait :stale do
      created_at { 99.days.ago }
      status { 'pending' }
    end

    trait :nil_form_data do
      association :submission, form_data: nil
    end
  end
end
