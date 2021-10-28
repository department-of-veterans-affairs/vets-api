# frozen_string_literal: true

FactoryBot.define do
  factory :preneed_attachment, class: 'Preneeds::PreneedAttachment' do
    after(:build) do |preneed_attachment|
      preneed_attachment.set_file_data!(
        Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf'), 'application/pdf')
      )
    end
  end
end
