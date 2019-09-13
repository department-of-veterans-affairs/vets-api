# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney, class: 'ClaimsApi::PowerOfAttorney' do
    id SecureRandom.uuid
    status 'submitted'
    auth_headers { {} }
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_2122_json_api.json"))
      json['data']['attributes']
    end

    after(:build) do |supporting_document|
      supporting_document.set_file_data!(
        Rack::Test::UploadedFile.new(
          "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
        ),
        'docType'
      )
    end
  end
end
