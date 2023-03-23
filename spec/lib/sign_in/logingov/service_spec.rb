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
      id_token: 'eyJraWQiOiJmNWNlMTIzOWUzOWQzZGE4MzZmOTYzYmNjZDg1Zjg1ZDU3ZDQzMzVjZmRjNmExNzAzOWYLOL' \
                'QzNjFhMThiMTNjIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiI2NWY5ZjNiNS01NDQ5LTQ3YTYtYjI3Mi05Z' \
                'DYwMTllN2MyZTMiLCJpc3MiOiJodHRwczovL2lkcC5pbnQuaWRlbnRpdHlzYW5kYm94Lmdvdi8iLCJlbWF' \
                'pbCPzPmpvaG4uYnJhbWxleUBhZGhvY3RlYW0udXMiLCJlbHqZbF92ZXJpZmllZCI6dHJ1ZSwiZ2l2ZW5fb' \
                'mFtZSI6IkpvaG4iLCJmYW1pb1bRfbmFtZSI6IkJyYW1sZXkiLCJiaXJ0aGRhdGUiOiIxOTg5LTAzLTI4Ii' \
                'wic29jaWFsX3NlY3VyaXR5X251bWJlciI6IjA1Ni03Ni03MTQ5IiwidmVyaWZpZWRfYXQiOjE2MzU0NjUy' \
                'ODYsImFjciI6Imh0dHA6Ly9pZG1hbmFnZW1lbnQuZ292L25zL2Fzc3VyYW5jZS9pYWwvMiIsIm5vbmNlIj' \
                'oiYjIwNjc1ZjZjYmYwYWQ5M2YyNGEwMzE3YWU3Njk5OTQiLCJhdWQiOiJ1cm46Z292OmdzYTpvcGVuaWRj' \
                'b25uZWN0LnByb2ZpbGVzOnNwOnNzbzp2YTpkZXZfc2lnbmluIiwianRpIjoicjA1aWJSenNXSjVrRnloM1' \
                'ZuVlYtZyIsImF0X2hhc2giOiJsX0dnQmxPc2dkd0tKemc2SEFDYlJBIiwiY19oYXNoIjoiY1otX2F3OERj' \
                'SUJGTEVpTE9QZVNFUSIsImV4cCI6MTY0NTY0MTY0NSwiaWF0IjoxNjQ1NjQwNzQ1LCJuYmYiOjE2NDU2ND' \
                'A3NDV9.S3-8X9clNcwlH2RU5sNoYf9HXpcgVK9UGUJumhL2-3rvznrt6yGvkXvY4FuUzWEcI22muxUjbbs' \
                'ZHjCfDImZ869NTWsI-DKohSNmNnyOom29LJRymJTn3htI5MNmpGwbmNWNuK5HgerPZblL44N1a_rqfTF4l' \
                'ANQX0u52iIVDarcexpX0e9yS1rEPqi3PDdcwN_1tUYox4us9rgzRZaaoa4iTlFfovY7dfgo_ewqv2EDh7J' \
                'SfJJQhFhyabkJ9HgNkkc4m0SHqztterZ6lHgIoiJdQot6wsL9pQTYzFzgHV830ltpjVUcLG5vMXw4Kqs3B' \
                'N9tdSToHdB50Paxyfq9kg'
    }
  end
  let(:user_info) do
    OpenStruct.new({
                     sub: user_uuid,
                     iss: 'https://idp.int.identitysandbox.gov/',
                     email: email,
                     email_verified: true,
                     given_name: first_name,
                     family_name: last_name,
                     address: address,
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
      postal_code: postal_code,
      region: region,
      locality: locality
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
  let(:state) { 'some-state' }
  let(:acr) { 'some-acr' }

  describe '#render_auth' do
    let(:response) { subject.render_auth(state: state, acr: acr).to_s }
    let(:expected_log) { "[SignIn][Logingov][Service] Rendering auth, state: #{state}, acr: #{acr}" }

    it 'logs information to rails logger' do
      expect(Rails.logger).to receive(:info).with(expected_log)
      response
    end

    it 'renders the oauth_get_form template' do
      expect(response).to include('form id="oauth-form"')
    end

    it 'directs to the Login.gov OAuth authorization page' do
      expect(response).to include('action="https://idp.int.identitysandbox.gov/openid_connect/authorize"')
    end
  end

  describe '#render_logout' do
    let(:client_id) { Settings.logingov.client_id }
    let(:logout_redirect_uri) { Settings.logingov.logout_redirect_uri }
    let(:expected_url_params) do
      {
        client_id: client_id,
        post_logout_redirect_uri: logout_redirect_uri,
        state: encoded_state
      }
    end
    let(:encoded_state) { Base64.encode64(state_payload.to_json) }
    let(:state_payload) do
      {
        logout_redirect: client_logout_redirect_uri,
        seed: seed
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
        seed: seed
      }
    end
    let(:seed) { 'some-seed' }
    let(:client_logout_redirect_uri) { 'some-client-logout-redirect-uri' }

    it 'renders the oauth_get_form template' do
      expect(subject.render_logout_redirect(encoded_state)).to include('form id="oauth-form"')
    end

    it 'directs to the expected logout redirect uri' do
      expect(subject.render_logout_redirect(encoded_state)).to include(client_logout_redirect_uri)
    end
  end

  describe '#token' do
    context 'when the request is successful' do
      let(:expected_log) { "[SignIn][Logingov][Service] Token Success, code: #{code}" }

      it 'logs information to rails logger' do
        VCR.use_cassette('identity/logingov_200_responses') do
          expect(Rails.logger).to receive(:info).with(expected_log)
          subject.token(code)
        end
      end

      it 'returns an access token' do
        VCR.use_cassette('identity/logingov_200_responses') do
          expect(subject.token(code)).to eq(token)
        end
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
  end

  describe '#user_info' do
    it 'returns user attributes' do
      VCR.use_cassette('identity/logingov_200_responses') do
        expect(subject.user_info(token)).to eq(user_info)
      end
    end

    context 'when log_credential is enabled in idme configuration' do
      before do
        allow_any_instance_of(SignIn::Logingov::Configuration).to receive(:log_credential).and_return(true)
        allow(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
      end

      it 'makes a call to mocked authentication writer to save the credential' do
        VCR.use_cassette('identity/logingov_200_responses') do
          expect(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
          subject.user_info(token)
        end
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
        service_name: service_name,
        csp_email: email,
        multifactor: multifactor,
        authn_context: authn_context,
        auto_uplevel: auto_uplevel
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
        postal_code: postal_code,
        state: region,
        city: locality,
        country: country
      }
    end
    let(:country) { 'USA' }
    let(:expected_attributes) do
      expected_standard_attributes.merge({ ssn: ssn.tr('-', ''),
                                           birth_date: birth_date,
                                           first_name: first_name,
                                           last_name: last_name,
                                           address: expected_address })
    end

    it 'returns expected attributes' do
      expect(subject.normalized_attributes(user_info, credential_level)).to eq(expected_attributes)
    end
  end
end
