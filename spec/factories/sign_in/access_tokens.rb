# frozen_string_literal: true

FactoryBot.define do
  factory :access_token, class: 'SignIn::AccessToken' do
    skip_create

    session_handle { create(:oauth_session).handle }
    client_id { create(:client_config).client_id }
    user_uuid { create(:user_account).id }
    audience { 'some-audience' }
    refresh_token_hash { SecureRandom.hex }
    parent_refresh_token_hash { SecureRandom.hex }
    anti_csrf_token { SecureRandom.hex }
    last_regeneration_time { Time.zone.now }
    version { SignIn::Constants::AccessToken::CURRENT_VERSION }
    expiration_time { Time.zone.now + SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
    created_time { Time.zone.now }

    initialize_with do
      new(session_handle: session_handle,
          user_uuid: user_uuid,
          client_id: client_id,
          audience: audience,
          refresh_token_hash: refresh_token_hash,
          parent_refresh_token_hash: parent_refresh_token_hash,
          anti_csrf_token: anti_csrf_token,
          last_regeneration_time: last_regeneration_time,
          version: version,
          expiration_time: expiration_time,
          created_time: created_time)
    end
  end
end
