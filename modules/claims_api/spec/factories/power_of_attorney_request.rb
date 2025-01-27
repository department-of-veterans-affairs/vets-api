# frozen_string_literal: true

FactoryBot.define do
  factory :claims_api_power_of_attorney_request, class: 'ClaimsApi::PowerOfAttorneyRequest' do
    id { SecureRandom.uuid }
    proc_id { rand.to_s[2..8] }
    veteran_icn { Faker::Alphanumeric.alphanumeric(number: 17) }
    poa_code { Faker::Alphanumeric.alphanumeric(number: 3) }
  end
end
