# frozen_string_literal: true

FactoryBot.define do
  factory :service_account_access_token, class: 'SignIn::ServiceAccountAccessToken' do
    skip_create

    service_account_id { create(:service_account_config).service_account_id }
    audience { SecureRandom.hex }
    version { SignIn::Constants::AccessToken::CURRENT_VERSION }
    scopes { [Faker::Internet.url] }
    user_identifier { Faker::Internet.email }
    expiration_time { Time.zone.now + SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
    created_time { Time.zone.now }

    initialize_with do
      new(service_account_id:,
          audience:,
          scopes:,
          user_identifier:,
          version:,
          expiration_time:,
          created_time:)
    end
  end
end
