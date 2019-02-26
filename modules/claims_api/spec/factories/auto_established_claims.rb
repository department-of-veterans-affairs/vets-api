# frozen_string_literal: true

FactoryBot.define do
  factory :auto_established_claim, class: 'ClaimsApi::AutoEstablishedClaim' do
    status 'pending'
    evss_id nil
    auth_headers nil
    form_data do
      JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_json_api.json"))['data']['attributes']
    end
  end
end
