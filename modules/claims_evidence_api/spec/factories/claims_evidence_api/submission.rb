# frozen_string_literal: true

FactoryBot.define do
  factory :claims_evidence_submission, class: 'ClaimsEvidenceApi::Submission' do
    created_at { Time.zone.now }
  end
end
