# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'

describe SignIn::Logingov::Service do
  let(:code) { '6805c923-9f37-4b47-a5c9-214391ddffd5' }
  let(:user_info) do
    OpenStruct.new({
                     sub: user_uuid,
                     iss: 'https://idp.int.identitysandbox.gov/',
                     email:,
                     email_verified: true,
                     all_emails:,
                     given_name: first_name,
                     family_name: last_name,
                     address:,
                     birthdate: birth_date,
                     social_security_number: ssn,
                     verified_at: 1_635_465_286
                   })
  end
  let(:first_name) { 'Bob' }
  let(:last_name) { 'User' }
  let(:birth_date) { '1993-01-01' }
  let(:ssn) { '999-11-9999' }
  let(:address) do
    {
      formatted: formatted_address,
      street_address: street,
      postal_code:,
      region:,
      locality:
    }
  end
  let(:formatted_address) { "#{street}\n#{locality}, #{region} #{postal_code}" }
  let(:street) { "1 Microsoft Way\nApt 3" }
  let(:postal_code) { '11364' }
  let(:region) { 'NY' }
  let(:locality) { 'Bayside' }
  let(:multifactor) { true }
  let(:email) { 'user@test.com' }
  let(:secondary_email) { 'user@secondaryemail.com' }
  let(:all_emails) { [email, secondary_email] }
  let(:user_uuid) { '12345678-0990-10a1-f038-2839ab281f90' }
  let(:success_callback_url) { 'http://localhost:3001/auth/login/callback?type=logingov' }
  let(:failure_callback_url) { 'http://localhost:3001/auth/login/callback?auth=fail&code=007' }
  let(:expected_authorization_page) { 'https://idp.int.identitysandbox.gov/openid_connect/authorize' }
  let(:state) { 'some-state' }
  let(:acr) { 'some-acr' }
  let(:operation) { 'some-operation' }
  let(:optional_scopes) { ['all_emails'] }
  let(:current_time) { 1_692_663_038 }
  let(:expiration_time) { 1_692_663_938 }

  describe '#render_auth' do
    let(:response) { subject.render_auth(state:, acr:, operation:).to_s }
    let(:expected_scopes) { ['profile', 'profile:verified_at', 'address', 'email', 'openid', 'social_security_number'] }
    let(:expected_scope_query) { "scope=#{CGI.escape(expected_scopes.join(' '))}" }
    let(:expected_optional_scopes) { described_class::OPTIONAL_SCOPES & optional_scopes }

    let(:expected_log) do
      "[SignIn][Logingov][Service] Rendering auth, state: #{state}, acr: #{acr}, operation: #{operation}, " \
        "optional_scopes: #{expected_optional_scopes}"
    end

    context 'when the optional scopes are not provided' do
      let(:optional_scopes) { [] }

      it 'logs information to rails logger' do
        expect(Rails.logger).to receive(:info).with(expected_log)
        response
      end

      it 'renders the expected redirect uri' do
        expect(response).to include(expected_authorization_page)
      end

      it 'contains the expected scopes' do
        expect(response).to include(expected_scope_query)
      end
    end

    context 'when the optional scopes are provided' do
      subject { described_class.new(optional_scopes:) }

      let(:expected_scopes) do
        ['profile', 'profile:verified_at', 'address', 'email', 'openid', 'social_security_number', 'all_emails']
      end

      context 'when it is a valid scope' do
        it 'logs information to rails logger' do
          expect(Rails.logger).to receive(:info).with(expected_log)
          response
        end

        it 'renders the expected redirect uri' do
          expect(response).to include(expected_authorization_page)
        end

        it 'contains the expected scopes' do
          expect(response).to include(expected_scope_query)
        end
      end

      context 'when it is an invalid scope' do
        let(:optional_scopes) { ['invalid_scope'] }
        let(:expected_scopes) do
          ['profile', 'profile:verified_at', 'address', 'email', 'openid', 'social_security_number']
        end

        it 'logs information to rails logger' do
          expect(Rails.logger).to receive(:info).with(expected_log)

          response
        end

        it 'contains the expected scopes' do
          expect(response).to include(expected_scope_query)
        end
      end
    end
  end

  describe '#render_logout' do
    let(:client_id) { IdentitySettings.logingov.client_id }
    let(:logout_redirect_uri) { IdentitySettings.logingov.logout_redirect_uri }
    let(:expected_url_params) do
      {
        client_id:,
        post_logout_redirect_uri: logout_redirect_uri,
        state: encoded_state
      }
    end
    let(:encoded_state) { Base64.encode64(state_payload.to_json) }
    let(:state_payload) do
      {
        logout_redirect: client_logout_redirect_uri,
        seed:
      }
    end
    let(:seed) { 'some-seed' }
    let(:expected_url_host) { IdentitySettings.logingov.oauth_url }
    let(:expected_url_path) { 'openid_connect/logout' }
    let(:expected_url) { "#{expected_url_host}/#{expected_url_path}?#{expected_url_params.to_query}" }
    let(:client_logout_redirect_uri) { 'some-client-logout-redirect-uri' }

    before { allow(SecureRandom).to receive(:hex).and_return(seed) }

    it 'returns expected logout url' do
      expect(subject.render_logout(client_logout_redirect_uri)).to eq(expected_url)
    end
  end

  describe '#render_logout_redirect' do
    let(:encoded_state) { Base64.encode64(state_payload.to_json) }
    let(:state_payload) do
      {
        logout_redirect: client_logout_redirect_uri,
        seed:
      }
    end
    let(:seed) { 'some-seed' }
    let(:client_logout_redirect_uri) { 'some-client-logout-redirect-uri' }

    it 'directs to the expected logout redirect uri' do
      expect(subject.render_logout_redirect(encoded_state)).to include(client_logout_redirect_uri)
    end
  end

  describe '#token' do
    let(:expected_jwks_fetch_log) { '[SignIn][Logingov][Service] Get Public JWKs Success' }

    before do
      Timecop.freeze(Time.zone.at(current_time))
    end

    after do
      Timecop.return
    end

    context 'when the request is successful' do
      let(:expected_token_log) { "[SignIn][Logingov][Service] Token Success, code: #{code}" }
      let(:expected_access_token) { 'mHO_gU3WooLm0xoDxIAulw' }
      let(:expected_logingov_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }

      it 'logs information to rails logger', vcr: { cassette_name: 'identity/logingov_200_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_jwks_fetch_log)
        expect(Rails.logger).to receive(:info).with(expected_token_log)
        subject.token(code)
      end

      it 'returns an access token', vcr: { cassette_name: 'identity/logingov_200_responses' } do
        expect(subject.token(code)[:access_token]).to eq(expected_access_token)
      end

      it 'returns a logingov acr', vcr: { cassette_name: 'identity/logingov_200_responses' } do
        expect(subject.token(code)[:logingov_acr]).to eq(expected_logingov_acr)
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "[SignIn][Logingov][Service] Cannot perform Token request, status: #{status}, description: #{description}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWT decoding does not match expected verification' do
      let(:expected_error) { SignIn::Logingov::Errors::JWTVerificationError }
      let(:expected_error_message) { '[SignIn][Logingov][Service] JWT body does not match signature' }

      it 'raises a jwe decode error with expected message',
         vcr: { cassette_name: 'identity/logingov_jwks_mismatched_signature' } do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWT has expired' do
      let(:current_time) { expiration_time + 100 }
      let(:expected_error) { SignIn::Logingov::Errors::JWTExpiredError }
      let(:expected_error_message) { '[SignIn][Logingov][Service] JWT has expired' }

      it 'raises a jwe expired error with expected message',
         vcr: { cassette_name: 'identity/logingov_200_responses' } do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWT is malformed' do
      let(:expected_error) { SignIn::Logingov::Errors::JWTDecodeError }
      let(:expected_error_message) { '[SignIn][Logingov][Service] JWT is malformed' }

      it 'raises a jwt malformed error with expected message',
         vcr: { cassette_name: 'identity/logingov_jwks_jwt_malformed' } do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWK is malformed' do
      let(:expected_error) { SignIn::Logingov::Errors::PublicJWKError }
      let(:expected_error_message) { '[SignIn][Logingov][Service] Public JWK is malformed' }

      it 'raises a jwt malformed error with expected message',
         vcr: { cassette_name: 'identity/logingov_jwks_malformed' } do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the public JWKs response is not cached' do
      let(:expected_jwks_fetch_log) { '[SignIn][Logingov][Service] Get Public JWKs Success' }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'fetches the public JWKs' do
        VCR.use_cassette('identity/logingov_200_responses') do
          subject.token(code)

          expect(Rails.logger).to have_received(:info).with(expected_jwks_fetch_log)
        end
      end
    end

    context 'when the public JWKs response is cached' do
      let(:cache_key) { 'logingov_public_jwks' }
      let(:cache_expiration) { 30.minutes }
      let(:redis_store) { ActiveSupport::Cache::RedisCacheStore.new(redis: MockRedis.new) }

      before do
        allow(Rails).to receive(:cache).and_return(redis_store)
        Rails.cache.clear
        allow(Rails.logger).to receive(:info)
      end

      after do
        Rails.cache.clear
      end

      it 'uses the cached JWKs response' do
        VCR.use_cassette('identity/logingov_200_responses') do
          subject.token(code)

          expect(Rails.logger).to have_received(:info).with(expected_jwks_fetch_log)
        end
        VCR.use_cassette('identity/logingov_200_responses') do
          expect(Rails.logger).not_to receive(:info).with(expected_jwks_fetch_log)
          subject.token(code)
        end
      end

      context 'when the JWK is not found in the cached JWKs' do
        let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:jwks) { JWT::JWK::Set.new([JWT::JWK::RSA.new(rsa_key)]) }
        let(:expected_jwk_reload_log) { '[SignIn][Logingov][Service] JWK not found, reloading public JWKs' }

        before do
          allow(Rails.cache).to receive(:delete_matched).and_call_original
        end

        it 'clears the cache and fetches the public JWKs again' do
          Rails.cache.write(cache_key, jwks)

          VCR.use_cassette('identity/logingov_200_responses') do
            subject.token(code)

            expect(Rails.cache).to have_received(:delete_matched).with(cache_key)
            expect(Rails.logger).to have_received(:info).with(expected_jwk_reload_log)
            expect(Rails.logger).to have_received(:info).with(expected_jwks_fetch_log)
            expect(Rails.cache.read(cache_key)).not_to eq(jwks)
          end
        end
      end
    end
  end

  describe '#user_info' do
    before do
      Timecop.freeze(Time.zone.at(current_time))
    end

    after do
      Timecop.return
    end

    it 'returns user attributes', vcr: { cassette_name: 'identity/logingov_200_responses' } do
      token = subject.token(code)
      expect(subject.user_info(token)).to eq(user_info)
    end

    context 'when log_credential is enabled in idme configuration' do
      before do
        allow_any_instance_of(SignIn::Logingov::Configuration).to receive(:log_credential).and_return(true)
        allow(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
      end

      it 'makes a call to mocked authentication writer to save the credential',
         vcr: { cassette_name: 'identity/logingov_200_responses' } do
        expect(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
        token = subject.token(code)
        subject.user_info(token)
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "[SignIn][Logingov][Service] Cannot perform UserInfo request, status: #{status}, description: #{description}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error: description }) }
      let(:token) { 'some-token' }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end
  end

  describe '#normalized_attributes' do
    let(:expected_standard_attributes) do
      {
        logingov_uuid: user_uuid,
        current_ial: SignIn::Constants::Auth::IAL_TWO,
        max_ial: SignIn::Constants::Auth::IAL_TWO,
        service_name:,
        csp_email: email,
        all_csp_emails: all_emails,
        multifactor:,
        authn_context:,
        auto_uplevel:
      }
    end
    let(:credential_level) do
      create(:credential_level, current_ial: SignIn::Constants::Auth::IAL_TWO,
                                max_ial: SignIn::Constants::Auth::IAL_TWO)
    end

    let(:service_name) { SignIn::Constants::Auth::LOGINGOV }
    let(:auth_broker) { SignIn::Constants::Auth::BROKER_CODE }
    let(:authn_context) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }
    let(:auto_uplevel) { false }
    let(:expected_address) do
      {
        street: street.split("\n").first,
        street2: street.split("\n").last,
        postal_code:,
        state: region,
        city: locality,
        country:
      }
    end
    let(:country) { 'USA' }
    let(:expected_attributes) do
      expected_standard_attributes.merge({ ssn: ssn.tr('-', ''),
                                           birth_date:,
                                           first_name:,
                                           last_name:,
                                           address: expected_address })
    end

    it 'returns expected attributes' do
      expect(subject.normalized_attributes(user_info, credential_level)).to eq(expected_attributes)
    end
  end
end
