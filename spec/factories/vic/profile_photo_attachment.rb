# frozen_string_literal: true

FactoryBot.define do
  factory :profile_photo_attachment, class: VIC::ProfilePhotoAttachment do
    transient do
      file_path(nil)
      file_type(nil)
      form(nil)
    end

    after(:build) do |attachment, evaluator|
      file_path = evaluator.file_path || Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf')
      file_type = evaluator.file_type || 'application/pdf'

      attachment.set_file_data!(
        Rack::Test::UploadedFile.new(file_path, file_type),
        evaluator.form
      )
    end
  end
end
