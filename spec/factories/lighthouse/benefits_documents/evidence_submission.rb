# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

FactoryBot.define do
  factory :bd_evidence_submission, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
  end

  factory :bd_evidence_submission_timeout, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.new(1985, 10, 26).utc }
  end

  factory :bd_evidence_submission_failed, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
  end
end
