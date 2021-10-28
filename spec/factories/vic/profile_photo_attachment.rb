# frozen_string_literal: true

FactoryBot.define do
  factory :profile_photo_attachment, class: 'VIC::ProfilePhotoAttachment' do
    transient do
      file_path { nil }
      file_type { nil }
    end

    after(:build) do |attachment, evaluator|
      file_path = evaluator.file_path || 'spec/fixtures/files/va.gif'
      file_type = evaluator.file_type || 'image/gif'

      attachment.set_file_data!(
        Rack::Test::UploadedFile.new(file_path, file_type)
      )
    end
  end
end
