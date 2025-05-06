# frozen_string_literal: true

FactoryBot.define do
  factory :bpds_submission_attempt, class: 'BPDS::SubmissionAttempt' do
    bpds_submission

    trait :pending do
      status { 'pending' }
    end

    trait :submitted do
      status { 'submitted' }
    end

    trait :failure do
      status { 'failure' }
    end
  end
end
