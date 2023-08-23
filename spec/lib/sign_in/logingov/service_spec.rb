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
  let(:user_uuid) { '12345678-0990-10a1-f038-2839ab281f90' }
  let(:success_callback_url) { 'http://localhost:3001/auth/login/callback?type=logingov' }
  let(:failure_callback_url) { 'http://localhost:3001/auth/login/callback?auth=fail&code=007' }
  let(:expected_authorization_page) { 'https://idp.int.identitysandbox.gov/openid_connect/authorize' }
  let(:state) { 'some-state' }
  let(:acr) { 'some-acr' }
  let(:current_time) { 1_692_663_038 }
  let(:expiration_time) { 1_692_663_938 }

  describe '#render_auth' do
    let(:response) { subject.render_auth(state:, acr:).to_s }
    let(:expected_log) { "[SignIn][Logingov][Service] Rendering auth, state: #{state}, acr: #{acr}" }

    it 'logs information to rails logger' do
      expect(Rails.logger).to receive(:info).with(expected_log)
      response
    end

    it 'renders the expected redirect uri' do
      expect(response).to include(expected_authorization_page)
    end
  end

  describe '#render_logout' do
    let(:client_id) { Settings.logingov.client_id }
    let(:logout_redirect_uri) { Settings.logingov.logout_redirect_uri }
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
    let(:expected_url_host) { Settings.logingov.oauth_url }
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
    before do
      Timecop.freeze(Time.zone.at(current_time))
      subject.send(:config).public_jwks = nil
    end

    after do
      Timecop.return
    end

    context 'when the request is successful' do
      let(:expected_jwks_log) { '[SignIn][Logingov][Service] Get Public JWKs Success' }
      let(:expected_token_log) { "[SignIn][Logingov][Service] Token Success, code: #{code}" }
      let(:expected_access_token) { 'mHO_gU3WooLm0xoDxIAulw' }
      let(:expected_logingov_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }

      it 'logs information to rails logger', vcr: { cassette_name: 'identity/logingov_200_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_jwks_log)
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
  end

  describe '#user_info' do
    before do
      Timecop.freeze(Time.zone.at(current_time))
      subject.send(:config).public_jwks = nil
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
