# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    sequence(:id) { |n| n }
    guid { SecureRandom.uuid }
    association :supportable, factory: :notice_of_disagreement
    upload_submission { create(:upload_submission, guid: SecureRandom.uuid) } # set the guid to pass uniqueness check

    trait :with_detail do
      detail { SecureRandom.alphanumeric(150) }
    end

    trait :with_nod do
      supportable { create(:notice_of_disagreement) }
    end
  end
end
