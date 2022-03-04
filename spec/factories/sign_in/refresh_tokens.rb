# frozen_string_literal: true

FactoryBot.define do
  factory :refresh_token, class: 'SignIn::RefreshToken' do
    skip_create

    user_uuid { create(:user).uuid }
    session_handle { 'some-session-handle' }
    parent_refresh_token_hash { nil }
    anti_csrf_token { SecureRandom.hex }
    nonce { SecureRandom.hex }
    version { SignIn::Constants::RefreshToken::CURRENT_VERSION }

    initialize_with do
      new(user_uuid: user_uuid,
          session_handle: session_handle,
          parent_refresh_token_hash: parent_refresh_token_hash,
          anti_csrf_token: anti_csrf_token,
          nonce: nonce,
          version: version)
    end
  end
end
