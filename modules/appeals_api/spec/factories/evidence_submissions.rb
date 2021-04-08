# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    sequence(:id) { |n| n }
    association :supportable, factory: :notice_of_disagreement

    trait :with_details do
      details { SecureRandom.alphanumeric(150) }
    end
  end
end
