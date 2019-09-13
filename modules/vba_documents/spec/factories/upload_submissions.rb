# frozen_string_literal: true

FactoryBot.define do
  factory :upload_submission, class: 'VBADocuments::UploadSubmission' do
    guid { 'f7027a14-6abd-4087-b397-3d84d445f4c3' }
    status { 'pending' }
    consumer_id { 'f7027a14-6abd-4087-b397-3d84d445f4c3' }
    consumer_name { 'adhoc' }

    trait :status_received do
      status { 'received' }
    end

    trait :status_uploaded do
      status { 'uploaded' }
    end

    trait :status_error do
      status { 'error' }
      code { 'DOC104' }
      detail { 'Upload rejected' }
    end
  end
end
