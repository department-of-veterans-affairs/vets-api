# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    id { SecureRandom.uuid }
    association :supportable, factory: :notice_of_disagreement
  end
end
