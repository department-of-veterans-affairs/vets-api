# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'
require 'sign_in/idme/service'

RSpec.describe V0::SignInController, type: :controller do
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

    shared_examples 'error response' do
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

      it_behaves_like 'error response'
    end

    context 'when grant_type param is arbitrary' do
      let(:grant_type_value) { 'some-grant-type' }
      let(:expected_error) { 'Grant type is not valid' }

      it_behaves_like 'error response'
    end

    context 'when grant_type is jwt-bearer' do
      let(:grant_type_value) { SignIn::Constants::Auth::JWT_BEARER_GRANT }
      let(:assertion_value) { nil }

      context 'and assertion is not a valid jwt' do
        let(:assertion_value) { 'some-assertion-value' }
        let(:expected_error) { 'Assertion is malformed' }

        it_behaves_like 'error response'
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

        it_behaves_like 'error response'
      end

      context 'and code is given' do
        let(:code_value) { 'some-code' }

        context 'and code does not match an existing code container' do
          let(:code) { { code: 'some-arbitrary-code' } }
          let(:expected_error) { 'Code is not valid' }

          it_behaves_like 'error response'
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

              it_behaves_like 'error response'
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

                it_behaves_like 'error response'
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

                  it_behaves_like 'error response'
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

              it_behaves_like 'error response'
            end

            context 'and client_assertion_type matches expected value' do
              let(:client_assertion_type_value) { SignIn::Constants::Urn::JWT_BEARER_CLIENT_AUTHENTICATION }

              context 'and client_assertion is not a valid jwt' do
                let(:client_assertion_value) { 'some-client-assertion' }
                let(:expected_error) { 'Client assertion is malformed' }

                it_behaves_like 'error response'
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
                    exp:
                  }
                end
                let(:iss) { client_id }
                let(:aud) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }
                let(:sub) { client_id }
                let(:jti) { 'some-jti' }
                let(:exp) { 1.month.since.to_i }
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

                    it_behaves_like 'error response'
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

    context 'when grant_type is token-exchange' do
      let(:grant_type_value) { SignIn::Constants::Auth::TOKEN_EXCHANGE_GRANT }

      context 'and subject token param is not given' do
        let(:subject_token) { {} }
        let(:expected_error) { "Subject token can't be blank" }

        it_behaves_like 'error response'
      end

      context 'and subject token type param is not given' do
        let(:subject_token_type) { {} }
        let(:expected_error) { "Subject token type can't be blank" }

        it_behaves_like 'error response'
      end

      context 'and actor_token param is not given' do
        let(:actor_token) { {} }
        let(:expected_error) { "Actor token can't be blank" }

        it_behaves_like 'error response'
      end

      context 'and client_id param is not given' do
        let(:client_id_param) { {} }
        let(:expected_error) { "Client can't be blank" }

        it_behaves_like 'error response'
      end

      context 'and subject token is not a valid access token' do
        let(:subject_token_value) { 'some-subject-token' }
        let(:expected_error) { 'Access token JWT is malformed' }

        it_behaves_like 'error response'
      end

      context 'and subject token is a valid access token' do
        let(:subject_token_value) { SignIn::AccessTokenJwtEncoder.new(access_token: current_access_token).perform }
        let(:current_access_token) do
          create(:access_token, session_handle: current_session.handle,
                                device_secret_hash: hashed_device_secret,
                                client_id:)
        end
        let!(:current_session) { create(:oauth_session, hashed_device_secret:, user_account:, user_verification:) }
        let(:hashed_device_secret) { Digest::SHA256.hexdigest(device_secret) }
        let(:user_account) { user_verification.user_account }
        let(:device_secret) { 'some-device-secret' }

        context 'and subject token type is arbitrary' do
          let(:subject_token_type_value) { 'some-subject-token' }
          let(:expected_error) { 'subject token type is invalid' }

          it_behaves_like 'error response'
        end

        context 'and subject token type is access token URN' do
          let(:subject_token_type_value) { SignIn::Constants::Urn::ACCESS_TOKEN }

          context 'and actor token is arbitrary' do
            let(:actor_token_value) { 'some-actor-token' }
            let(:expected_error) { 'actor token is invalid' }

            it_behaves_like 'error response'
          end

          context 'and actor token is a valid device_secret' do
            let(:actor_token_value) { device_secret }

            context 'and actor token type is invalid' do
              let(:actor_token_type_value) { 'some-actor-token-type' }
              let(:expected_error) { 'actor token type is invalid' }

              it_behaves_like 'error response'
            end

            context 'and actor token type is device_secret URN' do
              let(:actor_token_type_value) { SignIn::Constants::Urn::DEVICE_SECRET }
              let(:new_client_config) do
                create(:client_config,
                       enforced_terms: new_client_enforced_terms,
                       shared_sessions: new_client_shared_sessions,
                       authentication: new_client_authentication,
                       anti_csrf: new_client_anti_csrf)
              end
              let(:new_client_enforced_terms) { nil }
              let(:new_client_anti_csrf) { true }
              let(:new_client_authentication) { SignIn::Constants::Auth::COOKIE }

              context 'and client id is not associated with a valid client config' do
                let(:client_id_value) { 'some-arbitrary-client-id' }
                let(:expected_error) { 'client configuration not found' }

                it_behaves_like 'error response'
              end

              context 'and client id is associated with a valid client config' do
                let(:client_id_value) { new_client_config.client_id }

                context 'and client id is not associated with a shared sessions client' do
                  let(:new_client_shared_sessions) { false }
                  let(:expected_error) { 'tokens requested for client without shared sessions' }

                  it_behaves_like 'error response'
                end

                context 'and client id is associated with a shared sessions client' do
                  let(:new_client_shared_sessions) { true }

                  context 'and current session is not associated with a device sso enabled client' do
                    let(:shared_sessions) { false }
                    let(:expected_error) { 'token exchange requested from invalid client' }

                    it_behaves_like 'error response'
                  end

                  context 'and current session is associated with a device sso enabled client' do
                    let(:shared_sessions) { true }
                    let(:expected_generator_log) { '[SignInService] [SignIn::TokenResponseGenerator] token exchanged' }
                    let(:expected_log) { '[SignInService] [V0::SignInController] token' }

                    context 'and the retrieved UserVerification is locked' do
                      let(:user_verification) { create(:user_verification, locked: true) }
                      let(:expected_error) { 'Credential is locked' }

                      it_behaves_like 'error response'
                    end

                    context 'and new client config is configured with enforced terms' do
                      let(:new_client_enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                      context 'and authenticating user has accepted current terms of use' do
                        let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }

                        it 'returns ok status' do
                          expect(subject).to have_http_status(:ok)
                        end
                      end

                      context 'and authenticating user has not accepted current terms of use' do
                        let(:expected_error) { 'Terms of Use has not been accepted' }

                        it_behaves_like 'error response'
                      end
                    end

                    it 'creates an OAuthSession' do
                      expect { subject }.to change(SignIn::OAuthSession, :count).by(1)
                    end

                    it 'returns ok status' do
                      expect(subject).to have_http_status(:ok)
                    end

                    context 'and requested tokens are for a session that is configured as api auth' do
                      let!(:user) { create(:user, :api_auth, uuid: user_uuid) }
                      let(:new_client_authentication) { SignIn::Constants::Auth::API }

                      context 'and authentication is for a session set up for device sso' do
                        let(:shared_sessions) { true }
                        let(:device_sso) { true }

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
                      let(:new_client_authentication) { SignIn::Constants::Auth::COOKIE }
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
                        let(:new_client_anti_csrf) { true }
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
  end

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

    shared_examples 'error response' do
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

        it_behaves_like 'error response'
      end

      context 'and anti_csrf_token has been modified' do
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it_behaves_like 'error response'
      end
    end

    context 'when refresh_token is an arbitrary string' do
      let(:refresh_token) { 'some-refresh-token' }
      let(:expected_error) { 'Refresh token cannot be decrypted' }

      it_behaves_like 'error response'
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

        it_behaves_like 'error response'
      end

      context 'and nonce component has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[1] = 'some-modified-nonce-component'
          split_token.join('.')
        end
        let(:expected_error) { 'Refresh nonce is invalid' }

        it_behaves_like 'error response'
      end

      context 'and version has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[2] = 'some-modified-version-component'
          split_token.join('.')
        end
        let(:expected_error) { 'Refresh token version is invalid' }

        it_behaves_like 'error response'
      end

      context 'and refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it_behaves_like 'error response'
      end

      context 'and refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }

        before do
          session = session_container.session
          session.destroy!
        end

        it_behaves_like 'error response'
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

        it_behaves_like 'error response'
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

          it_behaves_like 'error response'
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

      it_behaves_like 'error response'
    end
  end

  describe 'POST revoke' do
    subject { post(:revoke, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let!(:user) { create(:user) }
    let(:user_uuid) { user.uuid }
    let(:refresh_token_param) { { refresh_token: } }
    let(:refresh_token) { 'example-refresh-token' }
    let(:anti_csrf_token_param) { { anti_csrf_token: } }
    let(:anti_csrf_token) { 'example-anti-csrf-token' }
    let(:enable_anti_csrf) { false }
    let(:user_verification) { user.user_verification }
    let(:user_account) { user.user_account }
    let(:validated_credential) do
      create(:validated_credential, user_verification:, client_config:)
    end
    let(:authentication) { SignIn::Constants::Auth::API }
    let!(:client_config) { create(:client_config, authentication:, anti_csrf:, enforced_terms:) }
    let(:enforced_terms) { nil }
    let(:anti_csrf) { false }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_revoke_failure) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] revoke error' }
      let(:expected_error_context) { { errors: expected_error.to_s } }

      before { allow(Rails.logger).to receive(:info) }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed revocation attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'updates StatsD with a revoke request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_revoke_failure)
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
      let(:expected_error_status) { :unauthorized }

      context 'and anti_csrf_token param is not given' do
        let(:anti_csrf_token_param) { {} }
        let(:anti_csrf_token) { nil }

        it_behaves_like 'error response'
      end

      context 'and anti_csrf_token has been modified' do
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it_behaves_like 'error response'
      end
    end

    context 'when refresh_token is a random string' do
      let(:expected_error) { 'Refresh token cannot be decrypted' }
      let(:expected_error_status) { :unauthorized }

      it_behaves_like 'error response'
    end

    context 'when refresh_token is encrypted correctly' do
      let(:session_container) do
        SignIn::SessionCreator.new(validated_credential:).perform
      end
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:expected_log_message) { '[SignInService] [V0::SignInController] revoke' }
      let(:statsd_revoke_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS }
      let(:expected_log_attributes) do
        {
          uuid: session_container.refresh_token.uuid,
          user_uuid:,
          session_handle: expected_session_handle,
          version: session_container.refresh_token.version
        }
      end

      context 'when refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it_behaves_like 'error response'
      end

      context 'when refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.destroy!
        end

        it_behaves_like 'error response'
      end

      context 'when refresh token is unmodified and valid' do
        let(:expected_session_handle) { session_container.session.handle }

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'destroys user session' do
          subject
          expect { session_container.session.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'logs the session revocation' do
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_attributes)
          subject
        end

        it 'updates StatsD with a revoke request success' do
          expect { subject }.to trigger_statsd_increment(statsd_revoke_success)
        end
      end
    end
  end

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
      let(:expected_error_context) { { errors: expected_error_message } }
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
      let(:expected_error_context) { { errors: expected_error_message } }

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
                                                      { errors: expected_error })
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
