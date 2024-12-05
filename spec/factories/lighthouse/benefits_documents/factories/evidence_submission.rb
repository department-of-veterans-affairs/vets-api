# frozen_string_literal: true

FactoryBot.define do
  factory :bd_evidence_submission, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
  end

  factory :bd_evidence_submission_timeout, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.new(1985, 10, 26).utc }
  end
end
