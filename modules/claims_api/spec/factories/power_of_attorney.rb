# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney, class: 'ClaimsApi::PowerOfAttorney' do
    id { SecureRandom.uuid }
    status { 'submitted' }
    auth_headers { { va_eauth_pnid: '796378881' } }
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_2122_json_api.json"))
      json['data']['attributes']
    end
    source_data { { name: 'Abe Lincoln', icn: '123', email: '1@2.com' } }

    trait :with_full_headers do
      auth_headers {
        {
          va_eauth_pnid: '796378881',
          va_eauth_birthdate: '1953-12-05',
          va_eauth_firstName: 'JESSE',
          va_eauth_lastName: 'GRAY'
        }
      }
    end

    trait :errored do
      status { 'errored' }
      vbms_error_message { 'An unknown error has occurred when uploading document' }
    end

    after(:build) do |power_of_attorney|
      power_of_attorney.set_file_data!(
        Rack::Test::UploadedFile.new(
          "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
        ),
        'docType'
      )
    end
  end

  factory :power_of_attorney_without_doc, class: 'ClaimsApi::PowerOfAttorney' do
    id { SecureRandom.uuid }
    status { 'pending' }
    auth_headers { {} }
    source_data { { name: 'Abe Lincoln', icn: '123', email: '1@2.com' } }
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_2122_json_api.json"))
      json['data']['attributes']
    end
  end
end
