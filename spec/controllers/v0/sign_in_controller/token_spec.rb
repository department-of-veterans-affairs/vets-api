# frozen_string_literal: true

require 'rails_helper'
require_relative 'sign_in_controller_shared_examples_spec'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'sign_in_controller_shared_setup'

  describe 'POST token' do
    subject do
      get(:token,
          params: {}
                  .merge(code)
                  .merge(code_verifier)
                  .merge(grant_type)
                  .merge(client_assertion)
                  .merge(client_assertion_type)
                  .merge(assertion)
                  .merge(subject_token)
                  .merge(subject_token_type)
                  .merge(actor_token)
                  .merge(actor_token_type)
                  .merge(client_id_param))
    end

    let(:user_verification) { create(:user_verification) }
    let(:user_verification_id) { user_verification.id }
    let!(:user) { create(:user, :loa3, user_verification:, user_account: user_verification.user_account) }
    let(:user_uuid) { user_verification.credential_identifier }
    let(:code) { { code: code_value } }
    let(:code_verifier) { { code_verifier: code_verifier_value } }
    let(:grant_type) { { grant_type: grant_type_value } }
    let(:assertion) { { assertion: assertion_value } }
    let(:subject_token) { { subject_token: subject_token_value } }
    let(:subject_token_type) { { subject_token_type: subject_token_type_value } }
    let(:actor_token) { { actor_token: actor_token_value } }
    let(:actor_token_type) { { actor_token_type: actor_token_type_value } }
    let(:client_id_param) { { client_id: client_id_value } }
    let(:assertion_value) { nil }
    let(:subject_token_value) { 'some-subject-token' }
    let(:subject_token_type_value) { 'some-subject-token-type' }
    let(:actor_token_value) { 'some-actor-token' }
    let(:actor_token_type_value) { 'some-actor-token-type' }
    let(:client_id_value) { 'some-client-id' }
    let(:code_value) { 'some-code' }
    let(:code_verifier_value) { 'some-code-verifier' }
    let(:grant_type_value) { SignIn::Constants::Auth::AUTH_CODE_GRANT }
    let(:client_assertion) { { client_assertion: client_assertion_value } }
    let(:client_assertion_type) { { client_assertion_type: client_assertion_type_value } }
    let(:client_assertion_value) { 'some-client-assertion' }
    let(:client_assertion_type_value) { nil }
    let(:type) { nil }
    let(:client_id) { client_config.client_id }
    let(:authentication) { SignIn::Constants::Auth::API }
    let!(:client_config) do
      create(:client_config,
             authentication:,
             anti_csrf:,
             pkce:,
             enforced_terms:,
             shared_sessions:)
    end
    let(:enforced_terms) { nil }
    let(:pkce) { true }
    let(:anti_csrf) { false }
    let(:loa) { nil }
    let(:shared_sessions) { false }
    let(:statsd_token_success) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS }
    let(:expected_error_status) { :bad_request }

    before { allow(Rails.logger).to receive(:info) }

    shared_examples 'token error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_token_failure) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] token error' }
      let(:expected_error_context) { { errors: expected_error.to_s } }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed token request' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'updates StatsD with a token request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_token_failure)
      end
    end

    context 'when grant_type param is not given' do
      let(:grant_type) { {} }
      let(:expected_error) { 'Grant type is not valid' }

      it_behaves_like 'token error response'
    end

    context 'when grant_type param is arbitrary' do
      let(:grant_type_value) { 'some-grant-type' }
      let(:expected_error) { 'Grant type is not valid' }

      it_behaves_like 'token error response'
    end

    context 'when grant_type is jwt-bearer' do
      let(:grant_type_value) { SignIn::Constants::Auth::JWT_BEARER_GRANT }
      let(:assertion_value) { nil }

      context 'and assertion is not a valid jwt' do
        let(:assertion_value) { 'some-assertion-value' }
        let(:expected_error) { 'Assertion is malformed' }

        it_behaves_like 'token error response'
      end

      context 'and assertion is a valid jwt' do
        let(:private_key) { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
        let(:private_key_path) { 'spec/fixtures/sign_in/sts_client.pem' }
        let(:assertion_payload) do
          {
            iss:,
            aud:,
            sub:,
            jti:,
            iat:,
            exp:,
            service_account_id:,
            scopes:
          }
        end
        let(:iss) { audience }
        let(:aud) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }
        let(:sub) { user_identifier }
        let(:jti) { 'some-jti' }
        let(:iat) { 1.month.ago.to_i }
        let(:exp) { 1.month.since.to_i }
        let(:user_identifier) { 'some-user-identifier' }
        let(:service_account_id) { service_account_config.service_account_id }
        let(:scopes) { [service_account_config.scopes.first] }
        let(:audience) { service_account_config.access_token_audience }
        let(:expiration_time) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES.since.to_i }
        let(:created_time) { Time.zone.now.to_i }
        let(:uuid) { 'some-uuid' }
        let(:version) { SignIn::Constants::AccessToken::CURRENT_VERSION }
        let(:assertion_certificate) do
          create(:sign_in_certificate, pem: File.read('spec/fixtures/sign_in/sts_client.crt'))
        end
        let(:service_account_config) { create(:service_account_config, certs: [assertion_certificate]) }
        let(:assertion_encode_algorithm) { SignIn::Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
        let(:assertion_value) do
          JWT.encode(assertion_payload, private_key, assertion_encode_algorithm)
        end
        let(:expected_log) { '[SignInService] [V0::SignInController] token' }
        let(:expected_log_values) { {} }

        before do
          allow(Rails.logger).to receive(:info)
          allow(SecureRandom).to receive(:uuid).and_return(uuid)
          Timecop.freeze
        end

        after do
          Timecop.return
        end

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'returns expected body with access token' do
          expect(JSON.parse(subject.body)['data']).to have_key('access_token')
        end

        it 'logs the successful token request' do
          expect(Rails.logger).to receive(:info).with(expected_log, expected_log_values)
          subject
        end

        it 'updates StatsD with a token request success' do
          expect { subject }.to trigger_statsd_increment(statsd_token_success)
        end
      end
    end

    context 'when grant_type is authorization_code' do
      let(:grant_type_value) { SignIn::Constants::Auth::AUTH_CODE_GRANT }

      context 'and code param is not given' do
        let(:code) { {} }
        let(:expected_error) { "Code can't be blank" }

        it_behaves_like 'token error response'
      end

      context 'and code is given' do
        let(:code_value) { 'some-code' }

        context 'and code does not match an existing code container' do
          let(:code) { { code: 'some-arbitrary-code' } }
          let(:expected_error) { 'Code is not valid' }

          it_behaves_like 'token error response'
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

              it_behaves_like 'token error response'
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

                it_behaves_like 'token error response'
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

                  it_behaves_like 'token error response'
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

    # Additional grant types and test cases would go here
    # Including private key JWT and token exchange tests
  end
end
