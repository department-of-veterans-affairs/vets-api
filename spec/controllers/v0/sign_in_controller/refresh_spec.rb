# frozen_string_literal: true

require 'rails_helper'
require_relative 'sign_in_controller_shared_examples_spec'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'sign_in_controller_shared_setup'

  describe 'POST refresh' do
    subject { post(:refresh, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let!(:user) { create(:user, uuid: user_uuid) }
    let(:user_uuid) { user_verification.credential_identifier }
    let(:refresh_token_param) { { refresh_token: } }
    let(:anti_csrf_token_param) { { anti_csrf_token: } }
    let(:refresh_token) { 'some-refresh-token' }
    let(:anti_csrf_token) { 'some-anti-csrf-token' }
    let(:user_verification) { create(:user_verification) }
    let(:user_account) { user_verification.user_account }
    let(:validated_credential) do
      create(:validated_credential, user_verification:, client_config:)
    end
    let(:authentication) { SignIn::Constants::Auth::API }
    let!(:client_config) { create(:client_config, authentication:, anti_csrf:, enforced_terms:) }
    let(:enforced_terms) { nil }
    let(:anti_csrf) { false }
    let(:expected_error_status) { :unauthorized }

    before { allow(Rails.logger).to receive(:info) }

    shared_examples 'refresh error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_refresh_error) { SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] refresh error' }
      let(:expected_error_context) { { errors: expected_error.to_s } }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed refresh attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'updates StatsD with a refresh request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_refresh_error)
      end
    end

    context 'when session has been configured with anti csrf enabled' do
      let(:anti_csrf) { true }
      let(:session_container) do
        SignIn::SessionCreator.new(validated_credential:).perform
      end
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:expected_error) { 'Anti CSRF token is not valid' }

      context 'and anti_csrf_token param is not given' do
        let(:anti_csrf_token_param) { {} }
        let(:anti_csrf_token) { nil }

        it_behaves_like 'refresh error response'
      end

      context 'and anti_csrf_token has been modified' do
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it_behaves_like 'refresh error response'
      end
    end

    context 'when refresh_token is an arbitrary string' do
      let(:refresh_token) { 'some-refresh-token' }
      let(:expected_error) { 'Refresh token cannot be decrypted' }

      it_behaves_like 'refresh error response'
    end

    context 'when refresh_token is the proper encrypted refresh token format' do
      let(:session_container) do
        SignIn::SessionCreator.new(validated_credential:).perform
      end
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:anti_csrf_token) { session_container.anti_csrf_token }
      let(:expected_session_handle) { session_container.session.handle }
      let(:expected_log_message) { '[SignInService] [V0::SignInController] refresh' }
      let(:statsd_refresh_success) { SignIn::Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS }
      let(:expected_log_attributes) do
        {
          token_type: 'Refresh',
          user_id: user_uuid,
          session_id: expected_session_handle
        }
      end

      context 'and encrypted component has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[0] = 'some-modified-encrypted-component'
          split_token.join
        end
        let(:expected_error) { 'Refresh token cannot be decrypted' }

        it_behaves_like 'refresh error response'
      end

      context 'and nonce component has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[1] = 'some-modified-nonce-component'
          split_token.join('.')
        end
        let(:expected_error) { 'Refresh nonce is invalid' }

        it_behaves_like 'refresh error response'
      end

      context 'and version has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[2] = 'some-modified-version-component'
          split_token.join('.')
        end
        let(:expected_error) { 'Refresh token version is invalid' }

        it_behaves_like 'refresh error response'
      end

      context 'and refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it_behaves_like 'refresh error response'
      end

      context 'and refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }

        before do
          session = session_container.session
          session.destroy!
        end

        it_behaves_like 'refresh error response'
      end

      context 'and refresh token is not a parent or child according to the session' do
        let(:expected_error) { 'Token theft detected' }

        before do
          session = session_container.session
          session.hashed_refresh_token = 'some-unrelated-refresh-token'
          session.save!
        end

        it 'destroys the existing session' do
          expect { subject }.to change(SignIn::OAuthSession, :count).from(1).to(0)
        end

        it_behaves_like 'refresh error response'
      end

      context 'and refresh token is unmodified and valid' do
        before { allow(Rails.logger).to receive(:info) }

        context 'and the retrieved UserVerification is locked' do
          let(:locked_user_verification) { create(:user_verification, locked: true) }
          let(:expected_error) { 'Credential is locked' }

          before do
            session = session_container.session
            session.user_verification = locked_user_verification
            session.save!
          end

          it_behaves_like 'refresh error response'
        end

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        context 'and refresh token is for a session that has been configured with api auth' do
          let(:authentication) { SignIn::Constants::Auth::API }
          let!(:user) { create(:user, :api_auth, uuid: user_uuid) }

          it 'returns expected body with access token' do
            expect(JSON.parse(subject.body)['data']).to have_key('access_token')
          end

          it 'returns expected body with refresh token' do
            expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
          end

          it 'logs the successful refresh request' do
            access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
            logger_context = {
              user_uuid: access_token['sub'],
              session_handle: access_token['session_handle'],
              client_id: access_token['client_id'],
              type: user_verification.credential_type,
              icn: user_account.icn
            }
            expect(Rails.logger).to have_received(:info).with(expected_log_message, logger_context)
          end

          it 'updates StatsD with a refresh request success' do
            expect { subject }.to trigger_statsd_increment(statsd_refresh_success)
          end
        end

        context 'and refresh token is for a session that has been configured with cookie auth' do
          let(:authentication) { SignIn::Constants::Auth::COOKIE }
          let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
          let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }

          it 'returns empty hash for body' do
            expect(JSON.parse(subject.body)).to eq({})
          end

          it 'sets access token cookie' do
            expect(subject.cookies).to have_key(access_token_cookie_name)
          end

          it 'sets refresh token cookie' do
            expect(subject.cookies).to have_key(refresh_token_cookie_name)
          end

          context 'and session has been configured with anti_csrf enabled' do
            let(:anti_csrf) { true }
            let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }

            it 'returns expected body with refresh token' do
              expect(subject.cookies).to have_key(anti_csrf_token_cookie_name)
            end
          end

          it 'logs the successful refresh request' do
            access_token_cookie = subject.cookies[access_token_cookie_name]
            access_token = JWT.decode(access_token_cookie, nil, false).first
            logger_context = {
              user_uuid: access_token['sub'],
              session_handle: access_token['session_handle'],
              client_id: access_token['client_id'],
              type: user_verification.credential_type,
              icn: user_account.icn
            }
            expect(Rails.logger).to have_received(:info).with(expected_log_message, logger_context)
          end

          it 'updates StatsD with a refresh request success' do
            expect { subject }.to trigger_statsd_increment(statsd_refresh_success)
          end
        end
      end
    end

    context 'when refresh_token param is not given' do
      let(:expected_error) { 'Refresh token is not defined' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:refresh_token_param) { {} }
      let(:refresh_token) { nil }
      let(:expected_error_status) { :bad_request }

      it_behaves_like 'refresh error response'
    end
  end
end
