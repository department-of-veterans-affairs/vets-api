# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    guid { SecureRandom.uuid }
    association :supportable, factory: :notice_of_disagreement
    upload_submission {
      create(:upload_submission, guid: SecureRandom.uuid, consumer_name: 'appeals_api_nod_evidence_submission')
    } # set the guid to pass uniqueness check
  end

  factory :sc_evidence_submission, class: 'AppealsApi::EvidenceSubmission' do
    guid { SecureRandom.uuid }
    association :supportable, factory: :supplemental_claim
    upload_submission {
      create(:upload_submission, guid: SecureRandom.uuid,
                                 consumer_name: 'appeals_api_sc_evidence_submission')
    } # set the guid to pass uniqueness check
  end

  trait :with_detail do
    detail { SecureRandom.alphanumeric(150) }
  end

  trait :status_error do
    upload_submission {
      create(:upload_submission, guid: SecureRandom.uuid, status: 'error',
                                 consumer_name: 'appeals_api_nod_evidence_submission')
    } # set the guid to pass uniqueness check
  end

  trait :with_code do
    code { 404 }
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
             detail: Faker::Lorem.sentence(word_count: 20))
    }
  end

  # For Notice of Disagreements v0:
  factory :evidence_submission_v0, class: 'AppealsApi::EvidenceSubmission', parent: :evidence_submission do
    association :supportable, factory: :notice_of_disagreement_v0
  end

  factory :evidence_submission_with_error_v0,
          class: 'AppealsApi::EvidenceSubmission',
          parent: :evidence_submission_with_error do
    association :supportable, factory: :notice_of_disagreement_v0
  end
  # For Supplemental Claims v0:
  factory :sc_evidence_submission_v0, class: 'AppealsApi::EvidenceSubmission', parent: :sc_evidence_submission do
    association :supportable, factory: :supplemental_claim_v0
  end
end
