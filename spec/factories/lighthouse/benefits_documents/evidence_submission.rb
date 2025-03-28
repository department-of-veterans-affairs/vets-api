# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

FactoryBot.define do
  factory :bd_evidence_submission, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
  end

  factory :bd_evidence_submission_for_deletion, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc - 61.days }
    delete_date { DateTime.now.utc - 1.day }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS] }
  end

  factory :bd_lh_evidence_submission_success, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    delete_date { DateTime.now.utc + 60.days }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS] }
    job_class { 'Lighthouse::BenefitsDocuments::Service' }
    request_id { 123_456 }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'testfile.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => nil
      } }.to_json
    end
  end

  factory :bd_evidence_submission_not_for_deletion, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc - 61.days }
    delete_date { DateTime.now.utc - 1.day }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
  end

  factory :bd_evidence_submission_timeout, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.new(1985, 10, 26).utc }
  end

  factory :bd_evidence_submission_created, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED] }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'testfile.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => nil
      } }.to_json
    end
  end

  factory :bd_evidence_submission_queued, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    job_id { 12_343 }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:QUEUED] }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'testfile.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => nil
      } }.to_json
    end
  end

  factory :bd_evidence_submission_pending, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING] }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'testfile.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => nil
      } }.to_json
    end
  end

  # Document Upload Failures for Type 1 errors occur in app/sidekiq/lighthouse/evidence_submissions/document_upload.rb
  # when a error happens before the document upload is sent to lighthouse
  factory :bd_lh_evidence_submission_failed_type1_error, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    job_class { 'Lighthouse::BenefitsDocuments::Service' }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    failed_date { DateTime.now.utc }
    acknowledgement_date { DateTime.now.utc + 30.days }
    error_message { 'Lighthouse::EvidenceSubmissions::DocumentUpload document upload failure' }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'test.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now)
      } }.to_json
    end
  end

  # Document Upload Failures for Type 2 errors occur in lib/lighthouse/benefits_documents/upload_status_updater.rb
  # when the polling job to grab the upload status from lighthouse occurs and there is a failure processing
  # the upload on lighthouses side
  factory :bd_lh_evidence_submission_failed_type2_error, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    job_class { 'Lighthouse::BenefitsDocuments::Service' }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    failed_date { DateTime.now.utc }
    acknowledgement_date { DateTime.now.utc + 30.days }
    error_message { 'test - there was an error returned from lh api' }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'test.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now)
      } }.to_json
    end
  end

  # Document Upload Failures for Type 1 errors occur in app/sidekiq/evss/document_upload.rb
  # when a error happens before or when we send the upload to evss
  factory :bd_evss_evidence_submission_failed_type1_error, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { DateTime.now.utc }
    job_class { 'EVSSClaimService' }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    failed_date { DateTime.now.utc }
    acknowledgement_date { DateTime.now.utc + 30.days }
    error_message { 'EVSS::DocumentUpload document upload failure' }
    template_metadata do
      { 'personalisation' => {
        'first_name' => 'test',
        'document_type' => 'Birth Certificate',
        'file_name' => 'test.txt',
        'obfuscated_file_name' => 'tesXXile.txt',
        'date_submitted' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now),
        'date_failed' => BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.now)
      } }.to_json
    end
  end

  factory :bd_evidence_submission_failed_va_notify_email_enqueued, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { 5.days.ago }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    job_class { 'BenefitsDocuments::Service' }
    va_notify_id { 123 }
    va_notify_date { DateTime.now.utc }
  end

  factory :bd_evss_evidence_submission_failed_va_notify_email_enqueued, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { 5.days.ago }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    job_class { 'EVSSClaimService' }
    va_notify_id { 222 }
    va_notify_date { DateTime.now.utc }
  end

  factory :bd_evidence_submission_failed_va_notify_email_queued, class: 'EvidenceSubmission' do
    association :user_account, factory: :user_account
    created_at { 5.days.ago }
    upload_status { BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED] }
    job_class { 'BenefitsDocuments::Service' }
    va_notify_id { 123 }
    va_notify_date { DateTime.now.utc }
    va_notify_status { 'success' }
  end
end
