# frozen_string_literal: true

FactoryBot.define do
  factory :claims_evidence_submission_attempt, class: 'ClaimsEvidenceApi::SubmissionAttempt' do
    created_at { Time.zone.now }

    trait 'pending' do
      status { 'pending' }
    end

    trait 'accepted' do
      status { 'accepted' }
    end

    trait 'failure' do
      status { 'failure' }
    end
  end
end
