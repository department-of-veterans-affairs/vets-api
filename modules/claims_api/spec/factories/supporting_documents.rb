# frozen_string_literal: true

FactoryBot.define do
  factory :supporting_document, class: 'ClaimsApi::SupportingDocument' do
    id { SecureRandom.uuid }
    auto_established_claim

    after(:build) do |supporting_document|
      supporting_document.set_file_data!(
        Rack::Test::UploadedFile.new(
          Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
        ),
        'docType',
        'description'
      )
    end
  end
end
