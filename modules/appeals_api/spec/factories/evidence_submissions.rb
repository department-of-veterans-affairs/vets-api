# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    sequence(:id) { |n| n }
    guid { SecureRandom.uuid }
    association :supportable, factory: :notice_of_disagreement
    upload_submission { create(:upload_submission, guid: SecureRandom.uuid) } # set the guid to pass uniqueness check
  end

  factory :evidence_submission_with_error, class: 'AppealsApi::EvidenceSubmission' do
    sequence(:id) { |n| n }
    guid { SecureRandom.uuid }
    association :supportable, factory: :notice_of_disagreement
    upload_submission {
      create(:upload_submission,
             guid: SecureRandom.uuid,
             status: 'error',
             code: '404',
             detail: SecureRandom.alphanumeric(150))
    }
  end
end
