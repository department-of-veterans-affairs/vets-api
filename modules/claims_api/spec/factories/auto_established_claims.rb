# frozen_string_literal: true

FactoryBot.define do
  factory :auto_established_claim, class: 'ClaimsApi::AutoEstablishedClaim' do
    id SecureRandom.uuid
    status 'pending'
    evss_id nil
    auth_headers { {} }
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_json_api.json"))
      json['data']['attributes']
    end
  end

  factory :invalid_auto_established_claim, class: 'ClaimsApi::AutoEstablishedClaim' do
    id SecureRandom.uuid
    status 'pending'
    evss_id nil
    auth_headers nil
    form_data do
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/invalid_form_526_json_api.json"))
      json['data']['attributes']
    end
  end
end
