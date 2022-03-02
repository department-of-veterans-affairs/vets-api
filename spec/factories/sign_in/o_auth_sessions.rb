# frozen_string_literal: true

FactoryBot.define do
  factory :oauth_session, class: 'SignIn::OAuthSession' do
    handle { SecureRandom.hex }
    user_account { create(:user_account) }
    hashed_refresh_token { SecureRandom.hex }
    refresh_expiration { Time.zone.now }
    refresh_creation { Time.zone.now + 1000 }
  end
end
