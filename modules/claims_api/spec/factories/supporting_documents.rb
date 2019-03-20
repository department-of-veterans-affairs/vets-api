# frozen_string_literal: true

FactoryBot.define do
  factory :supporting_document, class: ClaimsApi::SupportingDocument do
    auto_established_claim
    after(:build) do |supporting_document|
      supporting_document.set_file_data!(
        Rack::Test::UploadedFile.new(
          "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
        )
      )
    end
  end
end
