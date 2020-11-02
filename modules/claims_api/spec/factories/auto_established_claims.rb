# frozen_string_literal: true

FactoryBot.define do
  factory :auto_established_claim, class: 'ClaimsApi::AutoEstablishedClaim' do
    id { SecureRandom.uuid }
    status { 'pending' }
    source { 'oddball' }
    evss_id { nil }
    auth_headers { { test: ('a'..'z').to_a.shuffle.join } }
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_json_api.json"))
      json['data']['attributes']
    end

    trait :status_established do
      status { 'established' }
    end

    trait :status_errored do
      status { 'errored' }
      evss_response { 'something' }
    end
  end
end
