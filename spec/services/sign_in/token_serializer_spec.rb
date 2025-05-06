# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::TokenSerializer do
  let(:token_serializer) do
    SignIn::TokenSerializer.new(session_container:, cookies:)
  end

  describe '#perform' do
    subject { token_serializer.perform }

    let(:session_container) do
      create(:session_container,
             client_config:,
             refresh_token:,
             access_token:,
             anti_csrf_token:,
             device_secret:)
    end
    let(:cookies) { {} }
    let(:refresh_token) { create(:refresh_token) }
    let(:access_token) { create(:access_token) }
    let(:anti_csrf_token) { 'some-anti-csrf-token' }
    let(:client_config) do
      create(:client_config, authentication:, anti_csrf:, shared_sessions:, json_api_compatibility:)
    end
    let(:anti_csrf) { false }
    let(:json_api_compatibility) { true }
    let(:authentication) { SignIn::Constants::Auth::API }
    let(:device_secret) { 'some-device-secret' }
    let(:shared_sessions) { false }
    let(:encoded_access_token) do
      SignIn::AccessTokenJwtEncoder.new(access_token:).perform
    end
    let(:encrypted_refresh_token) do
      SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
    end

    context 'when client is configured with cookie based authentication' do
      let(:authentication) { SignIn::Constants::Auth::COOKIE }
      let(:access_token_expiration) { access_token.expiration_time }
      let(:refresh_token_expiration) { session_container.session.refresh_expiration }
      let(:info_cookie_value) do
        {
          access_token_expiration:,
          refresh_token_expiration:
        }
      end
      let(:path) { '/' }
      let(:secure) { IdentitySettings.sign_in.cookies_secure }
      let(:httponly) { true }
      let(:httponly_info_cookie) { false }
      let(:domain) { IdentitySettings.sign_in.info_cookie_domain }
      let(:refresh_path) { SignIn::Constants::Auth::REFRESH_ROUTE_PATH }
      let(:expected_access_token_cookie) do
        {
          value: encoded_access_token,
          expires: refresh_token_expiration,
          path:,
          secure:,
          httponly:,
          domain: :all
        }
      end
      let(:expected_refresh_token_cookie) do
        {
          value: encrypted_refresh_token,
          expires: refresh_token_expiration,
          path: refresh_path,
          secure:,
          httponly:
        }
      end
      let(:expected_anti_csrf_token_cookie) do
        {
          value: anti_csrf_token,
          expires: refresh_token_expiration,
          path:,
          secure:,
          httponly:
        }
      end
      let(:expected_info_cookie) do
        {
          value: info_cookie_value.to_json,
          expires: refresh_token_expiration,
          secure:,
          domain:,
          httponly: httponly_info_cookie,
          path:
        }
      end
      let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
      let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }
      let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }
      let(:info_cookie_name) { SignIn::Constants::Auth::INFO_COOKIE_NAME }

      it 'sets access token cookie' do
        subject
        expect(cookies[access_token_cookie_name]).to eq(expected_access_token_cookie)
      end

      it 'sets refresh token cookie' do
        subject
        expect(cookies[refresh_token_cookie_name]).to eq(expected_refresh_token_cookie)
      end

      it 'sets info cookie' do
        subject
        expect(cookies[info_cookie_name]).to eq(expected_info_cookie)
      end

      context 'and client is configured to check for anti csrf' do
        let(:anti_csrf) { true }

        it 'sets anti csrf token cookie' do
          subject
          expect(cookies[anti_csrf_token_cookie_name]).to eq(expected_anti_csrf_token_cookie)
        end

        it 'returns an empty hash' do
          expect(subject).to eq({})
        end
      end

      context 'and client is not configured to check for anti csrf' do
        let(:anti_csrf) { false }

        it 'does not anti csrf token cookie' do
          subject
          expect(cookies[anti_csrf_token_cookie_name]).to be_nil
        end

        it 'returns an empty hash' do
          expect(subject).to eq({})
        end
      end
    end

    context 'when client is configured with api based authentication' do
      let(:authentication) { SignIn::Constants::Auth::API }
      let(:expected_json_payload) { { data: token_payload } }

      context 'and client is not configured with shared sessions' do
        let(:token_payload) do
          { access_token: encoded_access_token, refresh_token: encrypted_refresh_token }
        end

        it 'returns expected json payload without device_secret' do
          expect(subject).to eq(expected_json_payload)
        end
      end

      context 'and client is configured with shared sessions' do
        let(:shared_sessions) { true }
        let(:token_payload) do
          { access_token: encoded_access_token, refresh_token: encrypted_refresh_token, device_secret: }
        end

        it 'returns expected json payload with device_secret' do
          expect(subject).to eq(expected_json_payload)
        end
      end

      context 'and client is not configured to check for anti csrf' do
        let(:anti_csrf) { false }
        let(:token_payload) { { access_token: encoded_access_token, refresh_token: encrypted_refresh_token } }

        it 'returns expected json payload without anti csrf token' do
          expect(subject).to eq(expected_json_payload)
        end
      end

      context 'and client is configured to check for anti csrf' do
        let(:anti_csrf) { true }
        let(:token_payload) do
          {
            access_token: encoded_access_token,
            refresh_token: encrypted_refresh_token,
            anti_csrf_token:
          }
        end

        it 'returns expected json payload with anti csrf token' do
          expect(subject).to eq(expected_json_payload)
        end
      end

      context 'and client is configured to be compatible with json api' do
        let(:json_api_compatibility) { true }
        let(:expected_json_payload) { { data: token_payload } }
        let(:token_payload) do
          {
            access_token: encoded_access_token,
            refresh_token: encrypted_refresh_token
          }
        end

        it 'returns expected json payload' do
          expect(subject).to eq(expected_json_payload)
        end
      end

      context 'and client is not configured to be compatible with json api' do
        let(:json_api_compatibility) { false }
        let(:expected_json_payload) { token_payload }
        let(:token_payload) do
          {
            access_token: encoded_access_token,
            refresh_token: encrypted_refresh_token
          }
        end

        it 'returns expected json payload' do
          expect(subject).to eq(expected_json_payload)
        end
      end
    end

    context 'when client is configured with mock based authentication' do
      let(:authentication) { SignIn::Constants::Auth::MOCK }
      let(:expected_json_payload) { { data: token_payload } }
      let(:access_token_expiration) { access_token.expiration_time }
      let(:refresh_token_expiration) { session_container.session.refresh_expiration }
      let(:info_cookie_value) do
        {
          access_token_expiration:,
          refresh_token_expiration:
        }
      end
      let(:path) { '/' }
      let(:secure) { IdentitySettings.sign_in.cookies_secure }
      let(:httponly) { true }
      let(:httponly_info_cookie) { false }
      let(:domain) { IdentitySettings.sign_in.info_cookie_domain }
      let(:refresh_path) { SignIn::Constants::Auth::REFRESH_ROUTE_PATH }
      let(:expected_access_token_cookie) do
        {
          value: encoded_access_token,
          expires: refresh_token_expiration,
          path:,
          secure:,
          httponly:,
          domain: :all
        }
      end
      let(:expected_refresh_token_cookie) do
        {
          value: encrypted_refresh_token,
          expires: refresh_token_expiration,
          path: refresh_path,
          secure:,
          httponly:
        }
      end
      let(:expected_anti_csrf_token_cookie) do
        {
          value: anti_csrf_token,
          expires: refresh_token_expiration,
          path:,
          secure:,
          httponly:
        }
      end
      let(:expected_info_cookie) do
        {
          value: info_cookie_value.to_json,
          expires: refresh_token_expiration,
          secure:,
          domain:,
          httponly: httponly_info_cookie,
          path:
        }
      end
      let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
      let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }
      let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }
      let(:info_cookie_name) { SignIn::Constants::Auth::INFO_COOKIE_NAME }

      it 'sets access token cookie' do
        subject
        expect(cookies[access_token_cookie_name]).to eq(expected_access_token_cookie)
      end

      it 'sets refresh token cookie' do
        subject
        expect(cookies[refresh_token_cookie_name]).to eq(expected_refresh_token_cookie)
      end

      it 'sets info cookie' do
        subject
        expect(cookies[info_cookie_name]).to eq(expected_info_cookie)
      end

      context 'and client is not configured to check for anti csrf' do
        let(:anti_csrf) { false }
        let(:token_payload) { { access_token: encoded_access_token, refresh_token: encrypted_refresh_token } }

        it 'returns expected json payload without anti csrf token' do
          expect(subject).to eq(expected_json_payload)
        end

        it 'does not anti csrf token cookie' do
          subject
          expect(cookies[anti_csrf_token_cookie_name]).to be_nil
        end
      end

      context 'and client is configured to check for anti csrf' do
        let(:anti_csrf) { true }
        let(:token_payload) do
          {
            access_token: encoded_access_token,
            refresh_token: encrypted_refresh_token,
            anti_csrf_token:
          }
        end

        it 'returns expected json payload with anti csrf token' do
          expect(subject).to eq(expected_json_payload)
        end

        it 'sets anti csrf token cookie' do
          subject
          expect(cookies[anti_csrf_token_cookie_name]).to eq(expected_anti_csrf_token_cookie)
        end
      end
    end
  end
end
