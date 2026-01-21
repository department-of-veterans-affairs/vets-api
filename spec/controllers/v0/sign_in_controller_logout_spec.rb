# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'logout_setup'

  describe 'GET logout' do
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

        it_behaves_like 'logout_authorization_error_response'
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

        it_behaves_like 'logout_authorization_error_response'
      end
    end

    context 'when client_id is arbitrary' do
      let(:client_id_value) { 'some-client-id' }
      let(:expected_error_status) { :ok }
      let(:expected_error) { SignIn::Errors::MalformedParamsError }
      let(:expected_error_message) { 'Client id is not valid' }
      let(:logout_redirect_uri) { nil }

      it_behaves_like 'logout_error_response'
    end
  end
end
