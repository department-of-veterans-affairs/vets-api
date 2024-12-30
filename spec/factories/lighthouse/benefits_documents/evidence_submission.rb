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

  factory :bd_evidence_submission_pending, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING] }
  end

  factory :bd_evidence_submission_failed, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    job_class { 'Lighthouse::BenefitsDocuments::DocumentUpload' }
    template_metadata_ciphertext do
      { 'personalisation' => {
        'first_name' => 'test',
        'filename' => 'test.txt',
        'date_submitted' => DateTime.now.utc.to_s,
        'date_failed' => DateTime.now.utc.to_s
      } }.to_json
    end
  end

  factory :bd_evidence_submission_failed_va_notify_email_enqueued, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { 5.days.ago }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    job_class { 'Lighthouse::BenefitsDocuments::DocumentUpload' }
    va_notify_id { 123 }
    va_notify_date { DateTime.now.utc }
  end

  factory :bd_evidence_submission_failed_va_notify_email_queued, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { 5.days.ago }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    job_class { 'Lighthouse::BenefitsDocuments::DocumentUpload' }
    va_notify_id { 123 }
    va_notify_date { DateTime.now.utc }
    va_notify_status { 'success' }
  end
end
