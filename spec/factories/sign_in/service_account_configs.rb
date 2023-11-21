# frozen_string_literal: true

FactoryBot.define do
  factory :service_account_config, class: 'SignIn::ServiceAccountConfig' do
    service_account_id { SecureRandom.hex }
    description { SecureRandom.hex }
    scopes { [Faker::Internet.url] }
    access_token_audience { SecureRandom.hex }
    access_token_duration { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
    certificates { [] }
  end
end
