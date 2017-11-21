FactoryBot.define do
  factory :preneed_attachment, class: Preneeds::PreneedAttachment do
    after(:build) do |preneed_attachment|
      preneed_attachment.set_file_data!(Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'pdf_fill', 'extras.pdf'), 'application/pdf'))
    end
  end
end
