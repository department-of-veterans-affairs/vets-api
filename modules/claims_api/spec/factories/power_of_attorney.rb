# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney, class: 'ClaimsApi::PowerOfAttorney',
                              parent: :claims_api_base_factory do
    id { SecureRandom.uuid }
    source_data { { name: 'Abe Lincoln', icn: '123', email: '1@2.com' } }
    current_poa { '074' }
    form_data do
      json = JSON.parse(File
             .read(Rails.root.join(*'/modules/claims_api/spec/fixtures/form_2122_json_api.json'.split('/')).to_s))
      json['data']['attributes']
    end
  end

  trait :vbms_error do
    status { 'errored' }
    vbms_error_message { 'A VBMS error has occurred' }
  end

  factory :power_of_attorney_with_doc, class: 'ClaimsApi::PowerOfAttorney',
                                       parent: :power_of_attorney do
    after(:build) do |power_of_attorney|
      power_of_attorney.set_file_data!(
        Rack::Test::UploadedFile.new(
          Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
        ),
        'docType'
      )
    end
  end
end
