# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney, class: 'ClaimsApi::PowerOfAttorney' do
    id SecureRandom.uuid
    status 'pending'
    auth_headers { {} }
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_2122_json_api.json"))
      json['data']['attributes']
    end
  end
end
