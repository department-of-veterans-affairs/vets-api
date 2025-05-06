# frozen_string_literal: true

FactoryBot.define do
  UPLOADED_PDF_PROPS = {
    source: nil, total_documents: 2, total_pages: 2,
    content: {
      page_count: 1,
      dimensions: { height: 11.0, width: 8.5, oversized_pdf: false },
      file_size: 12_040,
      sha256_checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      attachments: [
        {
          page_count: 1,
          dimensions: { height: 11.0, width: 8.5, oversized_pdf: false },
          file_size: 12_040,
          sha256_checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        }
      ]
    }
  }.freeze

  factory :upload_submission, class: 'VBADocuments::UploadSubmission' do
    guid { SecureRandom.uuid }
    status { 'pending' }
    consumer_id { 'f7027a14-6abd-4087-b397-3d84d445f4c3' }
    consumer_name { 'adhoc' }

    trait :status_received do
      status { 'received' }
    end

    trait :version_2 do
      metadata { { version: 2 } }
    end

    trait :status_uploaded do
      status { 'uploaded' }
      updated_at { Time.now.utc }
      uploaded_pdf { UPLOADED_PDF_PROPS }
    end

    trait :status_uploaded_11_min_ago do
      status { 'uploaded' }
      updated_at { 11.minutes.ago }
      uploaded_pdf { UPLOADED_PDF_PROPS }
    end

    trait :status_error do
      status { 'error' }
      code { 'DOC104' }
      detail { 'Upload rejected' }
    end

    trait :status_final_success do
      status { 'success' }
      metadata { { final_success_status: Time.now.utc } }
    end

    trait :skip_record_status_change_callback do
      after(:build) do |foo|
        class << foo
          def record_status_change
            true
          end
        end
      end
    end
  end

  factory :upload_submission_large_detail, class: 'VBADocuments::UploadSubmission', parent: :upload_submission do
    detail { 'abc' * 500 }
  end

  factory :upload_submission_manually_removed, class: 'VBADocuments::UploadSubmission' do
    guid { SecureRandom.uuid }
    status { 'received' }
    consumer_id { 'f7027a14-6abd-4087-b397-3d84d445f4c2' }
    consumer_name { 'adhoc' }
  end
end
