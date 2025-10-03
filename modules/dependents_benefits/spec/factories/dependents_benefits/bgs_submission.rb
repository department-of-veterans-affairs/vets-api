# frozen_string_literal: true

FactoryBot.define do
  factory :bgs_submission, class: 'BGS::Submission' do
    association :saved_claim, factory: :dependents_claim, strategy: :create
    form_id { '21-686C' }
    latest_status { 'pending' }
    saved_claim_id { saved_claim.id }
    reference_data_ciphertext { { icn: '1234567890V123456' } }
    encrypted_kms_key { 'test-kms-key' }
    needs_kms_rotation { false }
  end

  factory :bgs_submission_attempt, class: 'BGS::SubmissionAttempt' do
    association :submission, factory: :bgs_submission, strategy: :create
    status { 'pending' }
    metadata_ciphertext { { form_id: '21-686C' } }
    encrypted_kms_key { 'test-kms-key' }
    needs_kms_rotation { false }
  end
end
