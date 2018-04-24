# frozen_string_literal: true

FactoryBot.define do
  factory :upload_submission, class: 'VBADocuments::UploadSubmission' do
    guid 'f7027a14-6abd-4087-b397-3d84d445f4c3'
    status 'pending'

    trait :status_uploaded do
      status 'uploaded'
    end
  end
end
