# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'
require 'sign_in/idme/service'

RSpec.describe V0::SignIns::TokenController, type: :controller do
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
    let!(:user) { create(:user, :loa3, uuid: user_uuid) }
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
             certificates: [client_assertion_certificate],
             enforced_terms:,
             shared_sessions:)
    end
    let(:enforced_terms) { nil }
    let(:client_assertion_certificate) { nil }
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
      let(:expected_error_log) { '[SignInService] [V0::SignIns::TokenController] token error' }
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
        let(:certificate_path) { 'spec/fixtures/sign_in/sts_client.crt' }
        let(:version) { SignIn::Constants::AccessToken::CURRENT_VERSION }
        let(:assertion_certificate) { File.read(certificate_path) }
        let(:service_account_config) { create(:service_account_config, certificates: [assertion_certificate]) }
        let(:assertion_encode_algorithm) { SignIn::Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
        let(:assertion_value) do
          JWT.encode(assertion_payload, private_key, assertion_encode_algorithm)
        end
        let(:expected_log) { '[SignInService] [V0::SignIns::TokenController] token' }
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
              let(:expected_log) { '[SignInService] [V0::SignIns::TokenController] token' }
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
                let(:certificate_path) { 'spec/fixtures/sign_in/sample_client.crt' }
                let(:client_assertion_certificate) { File.read(certificate_path) }
                let(:user_verification_id) { user_verification.id }
                let(:user_verification) { create(:user_verification) }
                let(:expected_log) { '[SignInService] [V0::SignIns::TokenController] token' }
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
                    let(:expected_log) { '[SignInService] [V0::SignIns::TokenController] token' }

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
end
