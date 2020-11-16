# frozen_string_literal: true

FactoryBot.define do
  UPLOADED_PDF_PROPS = {
    source: nil, doc_type: 'Unknown', total_documents: 2, total_pages: 2,
    content: { page_count: 1, dimensions: { height: 8.5, width: 11.0, oversized_pdf: false },
               attachments: [{ page_count: 1, dimensions: { height: 8.5, width: 11.0, oversized_pdf: false } }] }
  }.freeze

  factory :upload_submission, class: 'VBADocuments::UploadSubmission' do
    guid { 'f7027a14-6abd-4087-b397-3d84d445f4c3' }
    status { 'pending' }
    consumer_id { 'f7027a14-6abd-4087-b397-3d84d445f4c3' }
    consumer_name { 'adhoc' }

    trait :status_received do
      status { 'received' }
    end

    trait :status_uploaded do
      guid { 'da65a6a3-4193-46f5-90de-12026ffd40a1' }
      status { 'uploaded' }
      uploaded_pdf { UPLOADED_PDF_PROPS }
    end

    trait :status_error do
      status { 'error' }
      code { 'DOC104' }
      detail { 'Upload rejected' }
    end
  end
end
