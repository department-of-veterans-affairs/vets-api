# frozen_string_literal: true

FactoryBot.define do
  factory :session_container, class: 'SignIn::SessionContainer' do
    skip_create

    session { create(:oauth_session) }
    refresh_token { create(:refresh_token) }
    access_token { create(:access_token) }
    anti_csrf_token { SecureRandom.hex }
    client_config { create(:client_config) }
    device_secret { SecureRandom.hex }

    initialize_with do
      new(session:,
          refresh_token:,
          access_token:,
          anti_csrf_token:,
          client_config:,
          device_secret:)
    end
  end
end
