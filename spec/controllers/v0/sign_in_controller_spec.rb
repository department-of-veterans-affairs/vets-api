# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'
require 'sign_in/idme/service'

RSpec.describe V0::SignInController, type: :controller do
  describe 'GET logout' do
    subject { get(:logout, params: logout_params) }

    let(:logout_params) do
      {}.merge(client_id)
    end
    let(:client_id) { { client_id: client_id_value } }
    let(:client_id_value) { client_config.client_id }
    let!(:client_config) { create(:client_config, logout_redirect_uri:) }
    let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
    let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
    let(:authorization) { "Bearer #{access_token}" }
    let(:oauth_session) { create(:oauth_session, user_verification:) }
    let(:user_verification) { create(:user_verification) }
    let(:access_token_object) do
      create(:access_token, session_handle: oauth_session.handle, client_id: client_config.client_id, expiration_time:)
    end
    let(:expiration_time) { Time.zone.now + SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }

    before do
      request.headers['Authorization'] = authorization
      allow(Rails.logger).to receive(:info)
    end

    shared_context 'error response' do
      let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] logout error' }
      let(:expected_error_context) { { errors: expected_error_message, client_id: client_id_value } }
      let(:expected_error_status) { :bad_request }
      let(:expected_error_json) { { 'errors' => expected_error_message } }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'triggers statsd increment for failed call' do
        expect { subject }.to trigger_statsd_increment(statsd_failure)
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end
    end

    shared_context 'authorization error response' do
      let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] logout error' }
      let(:expected_error_context) { { errors: expected_error_message, client_id: client_id_value } }

      it 'triggers statsd increment for failed call' do
        expect { subject }.to trigger_statsd_increment(statsd_failure)
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      context 'when client configuration has not configured a logout redirect uri' do
        let(:logout_redirect_uri) { nil }
        let(:expected_error_status) { :ok }

        it 'returns expected status' do
          expect(subject).to have_http_status(expected_error_status)
        end
      end

      context 'when client configuration has configured a logout redirect uri' do
        let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
        let(:expected_error_status) { :redirect }

        it 'returns expected status' do
          expect(subject).to have_http_status(expected_error_status)
        end

        it 'redirects to logout redirect url' do
          expect(subject).to redirect_to(logout_redirect_uri)
        end
      end
    end

    context 'when successfully authenticated' do
      let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS }
      let(:logingov_uuid) { 'some-logingov-uuid' }
      let(:expected_log) { '[SignInService] [V0::SignInController] logout' }
      let(:expected_log_params) do
        {
          uuid: access_token_object.uuid,
          user_uuid: access_token_object.user_uuid,
          session_handle: access_token_object.session_handle,
          client_id: access_token_object.client_id,
          audience: access_token_object.audience,
          version: access_token_object.version,
          last_regeneration_time: access_token_object.last_regeneration_time.to_i,
          created_time: access_token_object.created_time.to_i,
          expiration_time: access_token_object.expiration_time.to_i
        }
      end
      let(:expected_status) { :redirect }

      it 'deletes the OAuthSession object matching the session_handle in the access token' do
        expect { subject }.to change {
          SignIn::OAuthSession.find_by(handle: access_token_object.session_handle)
        }.from(oauth_session).to(nil)
      end

      it 'logs the logout call' do
        expect(Rails.logger).to receive(:info).with(expected_log, expected_log_params)
        subject
      end

      it 'triggers statsd increment for successful call' do
        expect { subject }.to trigger_statsd_increment(statsd_success)
      end

      context 'and authenticated credential is Login.gov' do
        let(:user_verification) { create(:logingov_user_verification) }

        context 'and client configuration has not configured a logout redirect uri' do
          let(:logout_redirect_uri) { nil }
          let(:expected_status) { :ok }

          it 'returns ok status' do
            expect(subject).to have_http_status(expected_status)
          end
        end

        context 'and client configuration has configured a logout redirect uri' do
          let(:logingov_client_id) { IdentitySettings.logingov.client_id }
          let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
          let(:logingov_logout_redirect_uri) { IdentitySettings.logingov.logout_redirect_uri }
          let(:random_seed) { 'some-random-seed' }
          let(:logout_state_payload) do
            {
              logout_redirect: client_config.logout_redirect_uri,
              seed: random_seed
            }
          end
          let(:state) { Base64.encode64(logout_state_payload.to_json) }
          let(:expected_url_params) do
            {
              client_id: logingov_client_id,
              post_logout_redirect_uri: logingov_logout_redirect_uri,
              state:
            }
          end
          let(:expected_url_host) { IdentitySettings.logingov.oauth_url }
          let(:expected_url_path) { 'openid_connect/logout' }
          let(:expected_url) { "#{expected_url_host}/#{expected_url_path}?#{expected_url_params.to_query}" }
          let(:expected_status) { :redirect }

          before { allow(SecureRandom).to receive(:hex).and_return(random_seed) }

          it 'returns redirect status' do
            expect(subject).to have_http_status(expected_status)
          end

          it 'redirects to login gov single sign out URL' do
            expect(subject).to redirect_to(expected_url)
          end
        end
      end

      context 'and authenticated credential is not Login.gov' do
        context 'and client configuration has not configured a logout redirect uri' do
          let(:logout_redirect_uri) { nil }
          let(:expected_status) { :ok }

          it 'returns ok status' do
            expect(subject).to have_http_status(expected_status)
          end
        end

        context 'and client configuration has configured a logout redirect uri' do
          let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
          let(:expected_status) { :redirect }

          it 'returns redirect status' do
            expect(subject).to have_http_status(expected_status)
          end

          it 'redirects to the configured logout redirect uri' do
            expect(subject).to redirect_to(logout_redirect_uri)
          end
        end
      end

      context 'and no session is found matching the access token session_handle' do
        let(:expected_error) { SignIn::Errors::SessionNotFoundError }
        let(:expected_error_message) { 'Session not found' }

        before { oauth_session.destroy! }

        it_behaves_like 'authorization error response'
      end
    end

    context 'when not successfully authenticated' do
      let(:expected_error) { 'Unable to authorize access token' }

      context 'and the access token is expired' do
        let(:expiration_time) { Time.zone.now - SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }

        it 'does not delete the OAuthSession object and clears cookies' do
          expect { subject }.not_to change(SignIn::OAuthSession, :count)
          expect(subject.cookies).to be_empty
        end

        it 'logs a logout error' do
          expect(Rails.logger).to receive(:info).with('[SignInService] [V0::SignInController] logout error',
                                                      { errors: expected_error, client_id: client_id_value })
          subject
        end

        context 'and client_id has a client configuration with a configured logout redirect uri' do
          let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
          let(:expected_status) { :redirect }

          it 'returns redirect status' do
            expect(subject).to have_http_status(expected_status)
          end

          it 'redirects to the configured logout redirect uri' do
            expect(subject).to redirect_to(logout_redirect_uri)
          end
        end

        context 'and client_id does not have a client configuration with a configured logout redirect uri' do
          let(:logout_redirect_uri) { nil }
          let(:expected_status) { :ok }

          it 'returns ok status' do
            expect(subject).to have_http_status(expected_status)
          end
        end
      end

      context 'and the access token is invalid' do
        let(:access_token) { 'some-invalid-access-token' }
        let(:expected_error) { SignIn::Errors::LogoutAuthorizationError }
        let(:expected_error_message) { 'Unable to authorize access token' }

        it_behaves_like 'authorization error response'
      end
    end

    context 'when client_id is arbitrary' do
      let(:client_id_value) { 'some-client-id' }
      let(:expected_error_status) { :ok }
      let(:expected_error) { SignIn::Errors::MalformedParamsError }
      let(:expected_error_message) { 'Client id is not valid' }
      let(:logout_redirect_uri) { nil }

      it_behaves_like 'error response'
    end
  end

  describe 'GET logingov_logout_proxy' do
    subject { get(:logingov_logout_proxy, params: logingov_logout_proxy_params) }

    let(:logingov_logout_proxy_params) do
      {}.merge(state)
    end
    let(:state) { { state: state_value } }
    let(:state_value) { 'some-state-value' }

    context 'when state param is not given' do
      let(:state) { {} }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] logingov_logout_proxy error' }
      let(:expected_error_message) do
        { errors: expected_error }
      end
      let(:expected_error) { 'State is not defined' }

      before { allow(Rails.logger).to receive(:info) }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed authorize attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
        subject
      end
    end

    context 'when state param is given' do
      let(:state_value) { encoded_state }
      let(:encoded_state) { Base64.encode64(state_payload.to_json) }
      let(:state_payload) do
        {
          logout_redirect: client_logout_redirect_uri,
          seed:
        }
      end
      let(:seed) { 'some-seed' }
      let(:client_logout_redirect_uri) { 'some-client-logout-redirect-uri' }

      it 'returns ok status' do
        expect(subject).to have_http_status(:ok)
      end

      it 'renders expected logout redirect uri in template' do
        expect(subject.body).to match(client_logout_redirect_uri)
      end
    end
  end

  describe 'GET revoke_all_sessions' do
    subject { get(:revoke_all_sessions) }

    shared_context 'error response' do
      let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE }
      let(:expected_error_json) { { 'errors' => expected_error_message } }
      let(:expected_error_status) { :unauthorized }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] revoke all sessions error' }
      let(:expected_error_context) { { errors: expected_error_message } }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed revoke all sessions call' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'triggers statsd increment for failed call' do
        expect { subject }.to trigger_statsd_increment(statsd_failure)
      end
    end

    context 'when successfully authenticated' do
      let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
      let(:authorization) { "Bearer #{access_token}" }
      let(:user) { create(:user, :loa3) }
      let(:user_verification) { user.user_verification }
      let(:user_account) { user.user_account }
      let(:user_uuid) { user.uuid }
      let(:oauth_session) { create(:oauth_session, user_account:) }
      let(:access_token_object) do
        create(:access_token, session_handle: oauth_session.handle, user_uuid:)
      end
      let(:oauth_session_count) { SignIn::OAuthSession.where(user_account:).count }
      let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS }
      let(:expected_log) { '[SignInService] [V0::SignInController] revoke all sessions' }
      let(:expected_log_params) do
        {
          uuid: access_token_object.uuid,
          user_uuid: access_token_object.user_uuid,
          session_handle: access_token_object.session_handle,
          client_id: access_token_object.client_id,
          audience: access_token_object.audience,
          version: access_token_object.version,
          last_regeneration_time: access_token_object.last_regeneration_time.to_i,
          created_time: access_token_object.created_time.to_i,
          expiration_time: access_token_object.expiration_time.to_i
        }
      end
      let(:expected_status) { :ok }

      before do
        request.headers['Authorization'] = authorization
      end

      it 'deletes all OAuthSession objects associated with current user user_account' do
        expect { subject }.to change(SignIn::OAuthSession, :count).from(oauth_session_count).to(0)
      end

      it 'returns ok status' do
        expect(subject).to have_http_status(expected_status)
      end

      it 'logs the revoke all sessions call' do
        expect(Rails.logger).to receive(:info).with(expected_log, expected_log_params)
        subject
      end

      it 'triggers statsd increment for successful call' do
        expect { subject }.to trigger_statsd_increment(statsd_success)
      end

      context 'and no session matches the access token session handle' do
        let(:expected_error) { SignIn::Errors::SessionNotFoundError }
        let(:expected_error_message) { 'Session not found' }

        before do
          oauth_session.destroy!
        end

        it_behaves_like 'error response'
      end

      context 'and some arbitrary Sign in Error is raised' do
        let(:expected_error) { SignIn::Errors::StandardError }
        let(:expected_error_message) { expected_error.to_s }

        before do
          allow(SignIn::RevokeSessionsForUser).to receive(:new).and_raise(expected_error.new(message: expected_error))
        end

        it_behaves_like 'error response'
      end
    end
  end
end
