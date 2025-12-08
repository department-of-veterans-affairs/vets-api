# frozen_string_literal: true

require 'rails_helper'

# This test was created to catch regressions from Rack version upgrades.
# See: https://github.com/department-of-veterans-affairs/vets-api/pull/25227
#
# Background:
# - In production, the reverse proxy terminates SSL and sets `X-Forwarded-Proto: https`
# - The app uses `cookies_secure: true` in production/staging
# - Rack uses `request.ssl?` to determine if cookies should be set with the Secure flag
# - Rack 3.x changed how it interprets forwarded headers for SSL detection
#
# The standard test helper uses `secure: false`, which bypasses this code path entirely.
# This test simulates the production environment where secure cookies and
# X-Forwarded-Proto are both in use.
RSpec.describe 'Rack SSL Detection for Secure Cookies', type: :request do
  describe 'X-Forwarded-Proto header handling' do
    # This is the critical test that verifies how Rack interprets the X-Forwarded-Proto header.
    # This is the core behavior that broke in Rack 3.x.
    #
    # If this test fails after a Rack upgrade, it means the SSL detection behavior has changed
    # and may break secure cookie authentication in production where:
    # 1. cookies_secure: true is set
    # 2. X-Forwarded-Proto: https is set by the reverse proxy
    #
    # The test works by instrumenting a controller to capture request.ssl? value.

    let(:captured_ssl_value) { [] }

    before do
      # Capture request.ssl? value during request processing
      allow_any_instance_of(ActionController::Metal).to receive(:process_action).and_wrap_original do |method, *args|
        # Capture the ssl? value before the action runs
        captured_ssl_value << method.receiver.request.ssl?
        method.call(*args)
      end
    end

    it 'sets request.ssl? to true when X-Forwarded-Proto is https' do
      get '/v0/maintenance_windows', headers: {
        'X-Forwarded-Proto' => 'https'
      }

      expect(response).not_to have_http_status(:internal_server_error)

      # This is the critical assertion - if Rack 3 changes how it interprets
      # X-Forwarded-Proto, this will fail, alerting us to the breaking change
      expect(captured_ssl_value.first).to be(true), <<~MSG
        request.ssl? returned #{captured_ssl_value.first.inspect} instead of true when X-Forwarded-Proto: https was set.
        This indicates Rack is not correctly interpreting the X-Forwarded-Proto header.

        In production, this will cause issues because:
        1. The reverse proxy terminates SSL and forwards X-Forwarded-Proto: https
        2. cookies_secure is set to true in staging/production
        3. If Rack doesn't recognize the request as SSL, Set-Cookie headers may not be handled correctly
        4. Browsers may not send secure cookies if the secure flag behavior changes

        See: https://github.com/department-of-veterans-affairs/vets-api/pull/25227
      MSG
    end

    it 'sets request.ssl? to true when HTTPS header is on' do
      get '/v0/maintenance_windows', headers: {
        'HTTPS' => 'on'
      }

      expect(response).not_to have_http_status(:internal_server_error)
      expect(captured_ssl_value.first).to be(true), <<~MSG
        request.ssl? returned #{captured_ssl_value.first.inspect} instead of true when HTTPS: on was set.
        This indicates Rack is not correctly interpreting the HTTPS header.
      MSG
    end

    it 'sets request.ssl? to false when no SSL headers are present' do
      get '/v0/maintenance_windows'

      expect(response).not_to have_http_status(:internal_server_error)
      expect(captured_ssl_value.first).to be(false), <<~MSG
        request.ssl? returned #{captured_ssl_value.first.inspect} instead of false when no SSL headers were set.
        This is a sanity check to ensure the test instrumentation is working correctly.
      MSG
    end
  end

  describe 'TokenSerializer secure cookie flag' do
    # This test verifies that TokenSerializer correctly uses the cookies_secure setting
    # when setting authentication cookies. This is the other half of the secure cookie flow.

    let(:user_account) { create(:user_account) }
    let(:oauth_session) { create(:oauth_session, user_account:) }
    let(:client_config) { create(:client_config, authentication: SignIn::Constants::Auth::COOKIE) }
    let(:access_token) do
      create(:access_token,
             session_handle: oauth_session.handle,
             user_uuid: user_account.id,
             client_id: client_config.client_id)
    end
    let(:refresh_token) do
      SignIn::RefreshToken.new(
        session_handle: oauth_session.handle,
        parent_refresh_token_hash: SecureRandom.hex,
        anti_csrf_token: SecureRandom.hex,
        user_uuid: user_account.id,
        nonce: SecureRandom.hex,
        version: SignIn::Constants::RefreshToken::CURRENT_VERSION
      )
    end
    let(:session_container) do
      SignIn::SessionContainer.new(
        session: oauth_session,
        refresh_token:,
        access_token:,
        anti_csrf_token: SecureRandom.hex,
        client_config:
      )
    end

    context 'when cookies_secure is true (production-like)' do
      before do
        allow(IdentitySettings.sign_in).to receive(:cookies_secure).and_return(true)
      end

      it 'sets cookies with secure: true' do
        mock_cookies = {}

        serializer = SignIn::TokenSerializer.new(
          session_container:,
          cookies: mock_cookies
        )

        serializer.perform

        expect(mock_cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME]).to include(secure: true)
      end
    end

    context 'when cookies_secure is false (development-like)' do
      before do
        allow(IdentitySettings.sign_in).to receive(:cookies_secure).and_return(false)
      end

      it 'sets cookies with secure: false' do
        mock_cookies = {}

        serializer = SignIn::TokenSerializer.new(
          session_container:,
          cookies: mock_cookies
        )

        serializer.perform

        expect(mock_cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME]).to include(secure: false)
      end
    end
  end
end
