# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'authorize_setup'

  describe 'GET authorize_sso' do
    subject { get(:authorize_sso, params: authorize_sso_params) }

    let(:client_id) { 'some-client-id' }
    let(:client_id_param) { client_id }
    let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
    let(:code_challenge_method) { 'S256' }
    let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:encode_algorithm) { SignIn::Constants::Auth::JWT_ENCODE_ALGORITHM }
    let(:state) { JWT.encode('some-state', private_key, encode_algorithm) }

    let(:authorize_sso_params) do
      {
        client_id: client_id_param,
        code_challenge:,
        code_challenge_method:,
        state:
      }
    end

    let(:shared_sessions) { true }
    let!(:client_config) do
      create(:client_config, shared_sessions:, json_api_compatibility: false, client_id:)
    end

    let!(:user_account) { create(:user_account) }
    let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
    let!(:user_verification) { create(:user_verification, user_account:) }

    let!(:existing_session_client_config) do
      create(:client_config, shared_sessions:, authentication: SignIn::Constants::Auth::COOKIE)
    end

    let!(:existing_session) do
      create(:oauth_session,
             client_id: existing_session_client_config.client_id,
             user_verification:,
             user_account:)
    end

    let(:existing_access_token) { create(:access_token, session_handle: existing_session.handle) }
    let(:existing_access_token_cookie) do
      SignIn::AccessTokenJwtEncoder.new(access_token: existing_access_token).perform if existing_access_token
    end

    before do
      request.cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = existing_access_token_cookie
      allow(Rails.logger).to receive(:info)
    end

    shared_examples 'a redirect to USIP' do
      let(:expected_redirect_uri) { 'http://localhost:3001/sign-in' }
      let(:expected_query_params) { authorize_sso_params.merge(oauth: true).to_query }
      let(:expected_log_message) { '[SignInService] [V0::SignInController] authorize sso redirect' }
      let(:expected_log_payload) do
        {
          error: expected_error_message,
          client_id: client_id_param
        }
      end

      it 'logs and redirects to USIP' do
        expect(subject).to redirect_to("#{expected_redirect_uri}?#{expected_query_params}")
        expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
      end
    end

    shared_examples 'an error response' do
      let(:expected_error_json) { { 'error' => expected_error_message } }
      let(:expected_error_status) { :bad_request }
      let(:expected_log_message) { '[SignInService] [V0::SignInController] authorize sso error' }
      let(:expected_log_payload) do
        {
          error: expected_error_message,
          client_id: client_id_param.to_s
        }
      end

      it 'logs and renders expected error' do
        response = subject
        expect(response).to have_http_status(expected_error_status)
        expect(JSON.parse(response.body)).to eq(expected_error_json)
        expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
      end
    end

    context 'when required params are invalid' do
      context 'when client_id is not given' do
        let(:client_id_param) { nil }
        let(:expected_error_message) { 'Invalid params: client_id' }

        it_behaves_like 'an error response'
      end

      context 'when code_challenge is not given' do
        let(:code_challenge) { nil }
        let(:expected_error_message) { 'Invalid params: code_challenge' }

        it_behaves_like 'an error response'
      end

      context 'when code_challenge_method is invalid' do
        let(:code_challenge_method) { 'invalid-method' }
        let(:expected_error_message) { 'Invalid params: code_challenge_method' }

        it_behaves_like 'an error response'
      end
    end

    context 'when required params are valid' do
      context 'and there is an error' do
        context 'when there is no existing access token' do
          let(:expected_error_message) { 'Access token JWT is malformed' }

          before { request.cookies.clear }

          it_behaves_like 'a redirect to USIP'
        end

        context 'when there is an existing access token' do
          context 'and the access token is expired' do
            let(:existing_access_token) { create(:access_token, expiration_time: 1.day.ago) }
            let(:expected_error_message) { 'Access token has expired' }

            it_behaves_like 'a redirect to USIP'
          end

          context 'and there is an error in the validator' do
            context 'when the session is not found' do
              let(:expected_error_message) { 'Session not authorized' }

              before do
                allow(SignIn::AuthSSO::SessionValidator).to receive(:new)
                  .and_raise(SignIn::Errors::SessionNotFoundError.new(message: expected_error_message))
              end

              it_behaves_like 'a redirect to USIP'
            end

            context 'when the client_configs are not valid' do
              let(:expected_error_message) { 'SSO requested for client without shared sessions' }
              let(:shared_sessions) { false }

              it_behaves_like 'a redirect to USIP'
            end

            context 'when there is a general error' do
              let(:expected_error_message) { 'An error occurred' }

              before do
                allow(SignIn::AuthSSO::SessionValidator).to receive(:new)
                  .and_raise(StandardError.new(expected_error_message))
              end

              it_behaves_like 'a redirect to USIP'
            end
          end
        end
      end

      context 'and there are no errors' do
        it 'renders an html response with a redirect to the client' do
          response = subject
          expect(response).to have_http_status(:found)
          expect(response.content_type).to eq('text/html; charset=utf-8')
          expect(response.body).to include("URL=#{client_config.redirect_uri}")
          expect(response.body).to include('code=')
          expect(response.body).to include("state=#{state}")
        end
      end
    end
  end
end
