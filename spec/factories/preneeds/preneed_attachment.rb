# frozen_string_literal: true

FactoryBot.define do
  factory :preneed_attachment, class: Preneeds::PreneedAttachment do
    # after(:build) do |preneed_attachment|
    #   preneed_attachment.set_file_data!(
    #     Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf'), 'application/pdf')
    #   )
    # end
    transient do
      file_path { nil }
      file_type { nil }
    end

    after(:build) do |attachment, evaluator|
      file_path = evaluator.file_path || Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf')
      file_type = evaluator.file_type || 'application/pdf'

      attachment.set_file_data!(
        Rack::Test::UploadedFile.new(file_path, file_type)
      )
    end
  end
end
