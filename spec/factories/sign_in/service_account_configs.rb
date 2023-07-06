# frozen_string_literal: true

FactoryBot.define do
  factory :service_account_config, class: 'SignIn::ServiceAccountConfig' do
    id { rand(1..1000) }
    service_account_id { SecureRandom.hex }
    description { 'Sign in Service Client Config Permissions' }
    scopes { ['https://dev-api.va.gov/v0/sign_in/client_config'] }
    access_token_audience { 'http://identity-dashboard-api-dev.vfs.va.gov' }
    access_token_duration { 5.minutes }
    certificates { [] }
    created_at { DateTime.now }
    updated_at { DateTime.now }
  end
end
