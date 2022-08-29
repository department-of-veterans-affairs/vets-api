# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'

describe SignIn::Logingov::Service do
  let(:code) { '6805c923-9f37-4b47-a5c9-214391ddffd5' }
  let(:token) do
    {
      access_token: 'AmCGxDQzUAr5rPZ4NgFvUQ',
      token_type: 'Bearer',
      expires_in: 900,
      # rubocop:disable Layout/LineLength
      id_token: 'eyJraWQiOiJmNWNlMTIzOWUzOWQzZGE4MzZmOTYzYmNjZDg1Zjg1ZDU3ZDQzMzVjZmRjNmExNzAzOWYLOLQzNjFhMThiMTNjIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiI2NWY5ZjNiNS01NDQ5LTQ3YTYtYjI3Mi05ZDYwMTllN2MyZTMiLCJpc3MiOiJodHRwczovL2lkcC5pbnQuaWRlbnRpdHlzYW5kYm94Lmdvdi8iLCJlbWFpbCPzPmpvaG4uYnJhbWxleUBhZGhvY3RlYW0udXMiLCJlbHqZbF92ZXJpZmllZCI6dHJ1ZSwiZ2l2ZW5fbmFtZSI6IkpvaG4iLCJmYW1pb1bRfbmFtZSI6IkJyYW1sZXkiLCJiaXJ0aGRhdGUiOiIxOTg5LTAzLTI4Iiwic29jaWFsX3NlY3VyaXR5X251bWJlciI6IjA1Ni03Ni03MTQ5IiwidmVyaWZpZWRfYXQiOjE2MzU0NjUyODYsImFjciI6Imh0dHA6Ly9pZG1hbmFnZW1lbnQuZ292L25zL2Fzc3VyYW5jZS9pYWwvMiIsIm5vbmNlIjoiYjIwNjc1ZjZjYmYwYWQ5M2YyNGEwMzE3YWU3Njk5OTQiLCJhdWQiOiJ1cm46Z292OmdzYTpvcGVuaWRjb25uZWN0LnByb2ZpbGVzOnNwOnNzbzp2YTpkZXZfc2lnbmluIiwianRpIjoicjA1aWJSenNXSjVrRnloM1ZuVlYtZyIsImF0X2hhc2giOiJsX0dnQmxPc2dkd0tKemc2SEFDYlJBIiwiY19oYXNoIjoiY1otX2F3OERjSUJGTEVpTE9QZVNFUSIsImV4cCI6MTY0NTY0MTY0NSwiaWF0IjoxNjQ1NjQwNzQ1LCJuYmYiOjE2NDU2NDA3NDV9.S3-8X9clNcwlH2RU5sNoYf9HXpcgVK9UGUJumhL2-3rvznrt6yGvkXvY4FuUzWEcI22muxUjbbsZHjCfDImZ869NTWsI-DKohSNmNnyOom29LJRymJTn3htI5MNmpGwbmNWNuK5HgerPZblL44N1a_rqfTF4lANQX0u52iIVDarcexpX0e9yS1rEPqi3PDdcwN_1tUYox4us9rgzRZaaoa4iTlFfovY7dfgo_ewqv2EDh7JSfJJQhFhyabkJ9HgNkkc4m0SHqztterZ6lHgIoiJdQot6wsL9pQTYzFzgHV830ltpjVUcLG5vMXw4Kqs3BN9tdSToHdB50Paxyfq9kg'
      # rubocop:enable Layout/LineLength
    }
  end
  let(:user_info) do
    {
      sub: user_uuid,
      iss: 'https://idp.int.identitysandbox.gov/',
      email: email,
      email_verified: true,
      given_name: first_name,
      family_name: last_name,
      birthdate: birth_date,
      social_security_number: ssn,
      verified_at: 1_635_465_286
    }
  end
  let(:first_name) { 'Bob' }
  let(:last_name) { 'User' }
  let(:birth_date) { '1993-01-01' }
  let(:ssn) { '999-11-9999' }
  let(:multifactor) { true }
  let(:email) { 'user@test.com' }
  let(:user_uuid) { '12345678-0990-10a1-f038-2839ab281f90' }
  let(:success_callback_url) { 'http://localhost:3001/auth/login/callback?type=logingov' }
  let(:failure_callback_url) { 'http://localhost:3001/auth/login/callback?auth=fail&code=007' }
  let(:state) { 'some-state' }
  let(:acr) { 'some-acr' }

  describe '#render_auth' do
    let(:response) { subject.render_auth(state: state, acr: acr).to_s }

    it 'renders the oauth_get_form template' do
      expect(response).to include('form id="oauth-form"')
    end

    it 'directs to the Login.gov OAuth authorization page' do
      expect(response).to include('action="https://idp.int.identitysandbox.gov/openid_connect/authorize"')
    end
  end

  describe '#render_logout' do
    let(:logingov_id_token) { 'some-logingov-id-token' }
    let(:logout_redirect_uri) { Settings.logingov.logout_redirect_uri }
    let(:expected_url_params) do
      {
        id_token_hint: logingov_id_token,
        post_logout_redirect_uri: logout_redirect_uri,
        state: state
      }
    end
    let(:expected_url_host) { Settings.logingov.oauth_url }
    let(:expected_url_path) { 'openid_connect/logout' }
    let(:expected_url) { "#{expected_url_host}/#{expected_url_path}?#{expected_url_params.to_query}" }

    before { allow(SecureRandom).to receive(:hex).and_return(state) }

    it 'renders expected logout url' do
      expect(subject.render_logout(id_token: logingov_id_token)).to eq(expected_url)
    end
  end

  describe '#token' do
    context 'when the request is successful' do
      it 'returns an access token' do
        VCR.use_cassette('identity/logingov_200_responses') do
          expect(subject.token(code)).to eq(token)
        end
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) { '[SignIn][Logingov][Service] Cannot perform Token request' }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
      end

      it 'raises a client error with expected message' do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end
  end

  describe '#user_info' do
    it 'returns a user attributes' do
      VCR.use_cassette('identity/logingov_200_responses') do
        expect(subject.user_info(token)).to eq(user_info)
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) { '[SignIn][Logingov][Service] Cannot perform UserInfo request' }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
      end

      it 'raises a client error with expected message' do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end
  end

  describe '#normalized_attributes' do
    let(:client_id) { SignIn::Constants::ClientConfig::COOKIE_AUTH }
    let(:expected_standard_attributes) do
      {
        uuid: user_uuid,
        logingov_uuid: user_uuid,
        loa: { current: LOA::THREE, highest: LOA::THREE },
        sign_in: { service_name: service_name, auth_broker: auth_broker,
                   client_id: SignIn::Constants::ClientConfig::COOKIE_AUTH },
        csp_email: email,
        multifactor: multifactor,
        authn_context: authn_context
      }
    end
    let(:credential_level) { create(:credential_level, current_ial: IAL::TWO, max_ial: IAL::TWO) }
    let(:service_name) { SAML::User::LOGINGOV_CSID }
    let(:auth_broker) { SignIn::Constants::Auth::BROKER_CODE }
    let(:authn_context) { IAL::LOGIN_GOV_IAL2 }
    let(:expected_attributes) do
      expected_standard_attributes.merge({ ssn: ssn.tr('-', ''),
                                           birth_date: birth_date,
                                           first_name: first_name,
                                           last_name: last_name })
    end

    it 'returns expected attributes' do
      expect(subject.normalized_attributes(user_info,
                                           credential_level,
                                           client_id)).to eq(expected_attributes)
    end
  end
end
