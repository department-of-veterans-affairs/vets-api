# frozen_string_literal: true

FactoryBot.define do
  factory :oauth_session, class: 'SignIn::OAuthSession' do
    handle { SecureRandom.uuid }
    user_account { create(:user_account) }
    client_id { SignIn::Constants::Auth::MOBILE_CLIENT }
    hashed_refresh_token { SecureRandom.hex }
    refresh_expiration { Time.zone.now + 1000 }
    refresh_creation { Time.zone.now }
    user_verification { create(:user_verification, user_account: user_account) }
    credential_email { Faker::Internet.email }
  end
end
