# frozen_string_literal: true

FactoryBot.define do
  factory :mock_credential_info, class: 'MockedAuthentication::MockCredentialInfo' do
    credential_info_code { SecureRandom.hex }
    credential_info { { type: 'logingov' } }
  end
end
