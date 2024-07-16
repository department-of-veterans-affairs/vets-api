# frozen_string_literal: true

FactoryBot.define do
  factory :form1010_ezr_attachment, class: 'Form1010EzrAttachment' do
    after(:build) do |ezr_attachment|
      ezr_attachment.set_file_data!(
        Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf'), 'application/pdf'
        )
      )
    end
  end

  factory :form1010_ezr_attachment2, class: 'Form1010EzrAttachment' do
    after(:build) do |ezr_attachment|
      ezr_attachment.set_file_data!(
        Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'form1010_ezr', 'attachment.pdf'), 'application/pdf'
        )
      )
    end
  end
end
