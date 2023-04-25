# frozen_string_literal: true

FactoryBot.define do
  factory :iam_user_identity, class: 'IAMUserIdentity' do
    authn_context { 'http://idmanagement.gov/ns/assurance/loa/3/vets' }
    email { 'va.api.user+idme.008@gmail.com' }
    first_name { 'GREG' }
    middle_name { 'A' }
    last_name { 'ANDERSON' }
    gender { 'M' }
    birth_date { '1970-08-12' }
    ssn { '796121200' }
    iam_sec_id { '0000028114' }
    icn { '1008596379V859838' }
    multifactor { true }
    iam_edipi { '1005079124' }
    expiration_timestamp { 1.day.from_now.to_i.to_s }

    sign_in do
      {
        service_name: 'oauth_IDME',
        auth_broker: SAML::URLService::BROKER_CODE
      }
    end

    loa do
      {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    end

    trait :appointments do
      icn { '24811694708759028' }
    end
  end
end
