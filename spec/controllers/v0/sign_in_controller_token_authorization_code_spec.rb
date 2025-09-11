# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'token_setup'

  describe 'POST token' do
    context 'when grant_type is authorization_code' do
      let(:grant_type_value) { SignIn::Constants::Auth::AUTH_CODE_GRANT }

      context 'and code param is not given' do
        let(:code) { {} }
        let(:expected_error) { "Code can't be blank" }

        it_behaves_like 'token_error_response'
      end

      context 'and code is given' do
        let(:code_value) { 'some-code' }

        context 'and code does not match an existing code container' do
          let(:code) { { code: 'some-arbitrary-code' } }
          let(:expected_error) { 'Code is not valid' }

          it_behaves_like 'token_error_response'
        end

        context 'and code does match an existing code container' do
          let(:code) { { code: code_value } }
          let(:code_value) { 'some-code-value' }
          let!(:code_container) do
            create(:code_container,
                   code: code_value,
                   code_challenge:,
                   client_id:,
                   user_verification_id:,
                   device_sso:)
          end
          let(:code_challenge) { 'some-code-challenge' }
          let(:device_sso) { false }

          context 'and client is configured with pkce authentication type' do
            let(:pkce) { true }

            context 'and code_verifier does not match expected code_challenge value' do
              let(:code_verifier_value) { 'some-arbitrary-code-verifier-value' }
              let(:expected_error) { 'Code Verifier is not valid' }

              it_behaves_like 'token_error_response'
            end

            context 'and code_verifier does match expected code_challenge value' do
              let(:code_verifier_value) { 'some-code-verifier-value' }
              let(:code_challenge) do
                hashed_code_challenge = Digest::SHA256.base64digest(code_verifier_value)
                Base64.urlsafe_encode64(Base64.urlsafe_decode64(hashed_code_challenge.to_s), padding: false)
              end
              let(:user_verification_id) { user_verification.id }
              let(:user_verification) { create(:user_verification) }
              let(:expected_log) { '[SignInService] [V0::SignInController] token' }
              let(:expected_generator_log) { '[SignInService] [SignIn::TokenResponseGenerator] session created' }

              before { allow(Rails.logger).to receive(:info) }

              context 'and the retrieved UserVerification is locked' do
                let(:user_verification) { create(:user_verification, locked: true) }
                let(:expected_error) { 'Credential is locked' }

                it_behaves_like 'token_error_response'
              end

              context 'and client config is configured with enforced terms' do
                let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                context 'and authenticating user has accepted current terms of use' do
                  let(:user_account) { user_verification.user_account }
                  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }

                  it 'returns ok status' do
                    expect(subject).to have_http_status(:ok)
                  end
                end

                context 'and authenticating user has not accepted current terms of use' do
                  let(:expected_error) { 'Terms of Use has not been accepted' }

                  it_behaves_like 'token_error_response'
                end
              end

              it 'creates an OAuthSession' do
                expect { subject }.to change(SignIn::OAuthSession, :count).by(1)
              end

              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              context 'and authentication is for a session that is configured as api auth' do
                let!(:user) { create(:user, :api_auth, uuid: user_uuid) }
                let(:authentication) { SignIn::Constants::Auth::API }

                context 'and authentication is for a session set up for device sso' do
                  let(:shared_sessions) { true }
                  let(:device_sso) { true }

                  it 'returns expected body with device_secret' do
                    expect(JSON.parse(subject.body)['data']).to have_key('device_secret')
                  end
                end

                context 'and authentication is for a session not set up for device sso' do
                  let(:shared_sessions) { true }
                  let(:device_sso) { false }

                  it 'returns expected body without device_secret' do
                    expect(JSON.parse(subject.body)['data']).not_to have_key('device_secret')
                  end
                end

                it 'returns expected body with access token' do
                  expect(JSON.parse(subject.body)['data']).to have_key('access_token')
                end

                it 'returns expected body with refresh token' do
                  expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
                end

                it 'logs the successful token request' do
                  access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
                  logger_context = {
                    uuid: access_token['jti'],
                    user_uuid: access_token['sub'],
                    session_handle: access_token['session_handle'],
                    client_id: access_token['client_id'],
                    audience: access_token['aud'],
                    version: access_token['version'],
                    last_regeneration_time: access_token['last_regeneration_time'],
                    created_time: access_token['iat'],
                    expiration_time: access_token['exp']
                  }
                  expect(Rails.logger).to have_received(:info).with(expected_log, {})
                  expect(Rails.logger).to have_received(:info).with(expected_generator_log, logger_context)
                end

                it 'updates StatsD with a token request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_token_success)
                end
              end

              context 'and authentication is for a session that is configured as cookie auth' do
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

                context 'and session is configured as anti csrf enabled' do
                  let(:anti_csrf) { true }
                  let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }

                  it 'returns expected body with refresh token' do
                    expect(subject.cookies).to have_key(anti_csrf_token_cookie_name)
                  end
                end

                it 'logs the successful token request' do
                  access_token_cookie = subject.cookies[access_token_cookie_name]
                  access_token = JWT.decode(access_token_cookie, nil, false).first
                  logger_context = {
                    uuid: access_token['jti'],
                    user_uuid: access_token['sub'],
                    session_handle: access_token['session_handle'],
                    client_id: access_token['client_id'],
                    audience: access_token['aud'],
                    version: access_token['version'],
                    last_regeneration_time: access_token['last_regeneration_time'],
                    created_time: access_token['iat'],
                    expiration_time: access_token['exp']
                  }
                  expect(Rails.logger).to have_received(:info).with(expected_log, {})
                  expect(Rails.logger).to have_received(:info).with(expected_generator_log, logger_context)
                end

                it 'updates StatsD with a token request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_token_success)
                end
              end
            end
          end

          context 'and client is configured with private key jwt authentication type' do
            let(:pkce) { false }

            context 'and client_assertion_type does not match expected value' do
              let(:client_assertion_type_value) { 'some-client-assertion-type' }
              let(:expected_error) { 'Client assertion type is not valid' }

              it_behaves_like 'token_error_response'
            end

            context 'and client_assertion_type matches expected value' do
              let(:client_assertion_type_value) { SignIn::Constants::Urn::JWT_BEARER_CLIENT_AUTHENTICATION }

              context 'and client_assertion is not a valid jwt' do
                let(:client_assertion_value) { 'some-client-assertion' }
                let(:expected_error) { 'Client assertion is malformed' }

                it_behaves_like 'token_error_response'
              end

              context 'and client_assertion is a valid jwt' do
                let!(:client_config) do
                  create(:client_config,
                         authentication:,
                         anti_csrf:,
                         pkce:,
                         enforced_terms:,
                         shared_sessions:,
                         certs:)
                end

                let(:private_key) { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
                let(:private_key_path) { 'spec/fixtures/sign_in/sample_client.pem' }
                let(:client_assertion_payload) do
                  {
                    iss:,
                    aud:,
                    sub:,
                    jti:,
                    exp:,
                    iat:
                  }
                end
                let(:iss) { client_id }
                let(:aud) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }
                let(:sub) { client_id }
                let(:jti) { 'some-jti' }
                let(:exp) { 1.month.since.to_i }
                let(:iat) { Time.current.to_i }
                let(:client_assertion_encode_algorithm) { SignIn::Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
                let(:client_assertion_value) do
                  JWT.encode(client_assertion_payload, private_key, client_assertion_encode_algorithm)
                end
                let(:certs) do
                  [create(:sign_in_certificate, pem: File.read('spec/fixtures/sign_in/sample_client.crt'))]
                end
                let(:user_verification_id) { user_verification.id }
                let(:user_verification) { create(:user_verification) }
                let(:expected_log) { '[SignInService] [V0::SignInController] token' }
                let(:expected_generator_log) { '[SignInService] [SignIn::TokenResponseGenerator] session created' }

                before { allow(Rails.logger).to receive(:info) }

                context 'and client config is configured with enforced terms' do
                  let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                  context 'and authenticating user has accepted current terms of use' do
                    let(:user_account) { user_verification.user_account }
                    let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }

                    it 'returns ok status' do
                      expect(subject).to have_http_status(:ok)
                    end
                  end

                  context 'and authenticating user has not accepted current terms of use' do
                    let(:expected_error) { 'Terms of Use has not been accepted' }

                    it_behaves_like 'token_error_response'
                  end
                end

                it 'creates an OAuthSession' do
                  expect { subject }.to change(SignIn::OAuthSession, :count).by(1)
                end

                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                context 'and authentication is for a session that is configured as api auth' do
                  let!(:user) { create(:user, :api_auth, uuid: user_uuid) }
                  let(:authentication) { SignIn::Constants::Auth::API }

                  context 'and authentication is for a session set up for device sso' do
                    let(:shared_sessions) { true }
                    let(:device_sso) { true }

                    it 'returns expected body with device_secret' do
                      expect(JSON.parse(subject.body)['data']).to have_key('device_secret')
                    end
                  end

                  context 'and authentication is for a session not set up for device sso' do
                    let(:shared_sessions) { true }
                    let(:device_sso) { false }

                    it 'returns expected body without device_secret' do
                      expect(JSON.parse(subject.body)['data']).not_to have_key('device_secret')
                    end
                  end

                  it 'returns expected body with access token' do
                    expect(JSON.parse(subject.body)['data']).to have_key('access_token')
                  end

                  it 'returns expected body with refresh token' do
                    expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
                  end

                  it 'logs the successful token request' do
                    access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
                    logger_context = {
                      uuid: access_token['jti'],
                      user_uuid: access_token['sub'],
                      session_handle: access_token['session_handle'],
                      client_id: access_token['client_id'],
                      audience: access_token['aud'],
                      version: access_token['version'],
                      last_regeneration_time: access_token['last_regeneration_time'],
                      created_time: access_token['iat'],
                      expiration_time: access_token['exp']
                    }
                    expect(Rails.logger).to have_received(:info).with(expected_log, {})
                    expect(Rails.logger).to have_received(:info).with(expected_generator_log, logger_context)
                  end

                  it 'updates StatsD with a token request success' do
                    expect { subject }.to trigger_statsd_increment(statsd_token_success)
                  end
                end

                context 'and authentication is for a session that is configured as cookie auth' do
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

                  context 'and session is configured as anti csrf enabled' do
                    let(:anti_csrf) { true }
                    let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }

                    it 'returns expected body with refresh token' do
                      expect(subject.cookies).to have_key(anti_csrf_token_cookie_name)
                    end
                  end

                  it 'logs the successful token request' do
                    access_token_cookie = subject.cookies[access_token_cookie_name]
                    access_token = JWT.decode(access_token_cookie, nil, false).first
                    logger_context = {
                      uuid: access_token['jti'],
                      user_uuid: access_token['sub'],
                      session_handle: access_token['session_handle'],
                      client_id: access_token['client_id'],
                      audience: access_token['aud'],
                      version: access_token['version'],
                      last_regeneration_time: access_token['last_regeneration_time'],
                      created_time: access_token['iat'],
                      expiration_time: access_token['exp']
                    }
                    expect(Rails.logger).to have_received(:info).with(expected_log, {})
                    expect(Rails.logger).to have_received(:info).with(expected_generator_log, logger_context)
                  end

                  it 'updates StatsD with a token request success' do
                    expect { subject }.to trigger_statsd_increment(statsd_token_success)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
