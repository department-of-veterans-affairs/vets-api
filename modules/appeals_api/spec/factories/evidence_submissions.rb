# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    sequence(:id) { |n| n }
    guid { SecureRandom.uuid }
    upload_submission { create(:upload_submission, guid: SecureRandom.uuid) } # set the guid to pass uniqueness check

    trait :with_detail do
      detail { SecureRandom.alphanumeric(150) }
    end
  end
end
