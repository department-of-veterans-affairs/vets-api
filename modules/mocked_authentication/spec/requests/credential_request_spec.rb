# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mocked Authentication Mock Credential', type: :request do
  describe 'GET authorize' do
    subject do
      get(authorize_path, params: authorize_params)
    end

    let(:authorize_path) { '/mocked_authentication/authorize' }
    let(:authorize_params) { {}.merge(credential_info).merge(state).merge(error) }
    let(:credential_info) { { credential_info: credential_info_value } }
    let(:credential_info_value) { Base64.encode64({ credential: 'some-credential' }.to_json) }
    let(:state) { { state: state_value } }
    let(:error) { { error: error_value } }
    let(:state_value) { 'some-state' }
    let(:error_value) { 'some-error' }

    shared_examples 'error response' do
      let(:expected_status) { :bad_request }
      let(:expected_error_hash) { { 'errors' => expected_error_message } }

      it 'returns expected status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'renders expected error' do
        subject
        expect(JSON.parse(response.body)).to eq(expected_error_hash)
      end
    end

    shared_examples 'successful response' do
      let(:expected_status) { :redirect }
      let(:expected_code) { 'some-code' }
      let(:expected_redirect_url) do
        "/v0/sign_in/callback?code=#{expected_code}&state=#{state_value}"
      end

      before { allow(SecureRandom).to receive(:hex).and_return(expected_code) }

      it 'returns a redirect status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'redirects to expected url' do
        subject
        expect(response).to redirect_to(expected_redirect_url)
      end

      it 'creates a new CredentialInfo associated with returned code' do
        subject
        expect(MockedAuthentication::CredentialInfo.find(expected_code)).not_to be_nil
      end
    end

    context 'when state is not defined' do
      let(:state) { {} }
      let(:expected_error_message) { 'State is not defined' }

      it_behaves_like 'error response'
    end

    context 'when state is defined' do
      let(:state) { { state: state_value } }

      context 'when credential info is not defined' do
        let(:credential_info) { {} }

        context 'and error is not defined' do
          let(:error) { {} }
          let(:expected_error_message) { 'Credential Info is not defined' }

          it_behaves_like 'error response'
        end

        context 'and error is defined' do
          let(:error_value) { 'some-error' }

          let(:expected_status) { :redirect }
          let(:expected_code) { 'some-code' }
          let(:expected_redirect_url) { "/v0/sign_in/callback?error=#{error_value}&state=#{state_value}" }

          it 'returns a redirect status' do
            subject
            expect(response).to have_http_status(expected_status)
          end

          it 'redirects to expected url' do
            subject
            expect(response).to redirect_to(expected_redirect_url)
          end
        end
      end

      context 'when credential info is defined' do
        let(:credential_info) { { credential_info: credential_info_value } }

        context 'and error is not defined' do
          let(:error) { {} }

          it_behaves_like 'successful response'
        end

        context 'and error is defined' do
          let(:error_value) { 'some-error' }

          let(:expected_status) { :redirect }
          let(:expected_code) { 'some-code' }
          let(:expected_redirect_url) { "/v0/sign_in/callback?error=#{error_value}&state=#{state_value}" }

          it 'returns a redirect status' do
            subject
            expect(response).to have_http_status(expected_status)
          end

          it 'redirects to expected url' do
            subject
            expect(response).to redirect_to(expected_redirect_url)
          end
        end
      end
    end
  end

  describe 'GET credential_list' do
    subject { get(credential_list_path, params: credential_list_params) }

    let(:credential_list_path) { '/mocked_authentication/credential_list' }
    let(:credential_list_params) { { type: credential_type } }
    let(:credential_type) { 'logingov' }
    let(:vets_api_mockdata_stub) do
      File.join(MockedAuthentication::Engine.root, 'spec', 'fixtures', 'credential_mock_data')
    end
    let(:mock_creds_filepath) { File.join(vets_api_mockdata_stub, 'credentials', credential_type) }
    let(:mock_user_zero) { File.read("#{mock_creds_filepath}/vetsgovuser0.json") }
    let(:mock_user_one) { File.read("#{mock_creds_filepath}/vetsgovuser1.json") }
    let(:mock_user_two_two_eight) { File.read("#{mock_creds_filepath}/vetsgovuser228.json") }
    let(:expected_mock_data) do
      { 'vetsgovuser0' => { 'credential_payload' => JSON.parse(mock_user_zero),
                            'encoded_credential' => Base64.encode64(mock_user_zero) },
        'vetsgovuser1' => { 'credential_payload' => JSON.parse(mock_user_one),
                            'encoded_credential' => Base64.encode64(mock_user_one) },
        'vetsgovuser228' => { 'credential_payload' => JSON.parse(mock_user_two_two_eight),
                              'encoded_credential' => Base64.encode64(mock_user_two_two_eight) } }
    end

    before { allow(Settings.betamocks).to receive(:cache_dir).and_return(vets_api_mockdata_stub) }

    shared_examples 'error response' do
      let(:expected_status) { :bad_request }
      let(:expected_error_hash) { { 'errors' => expected_error_message } }

      it 'returns expected status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'renders expected error' do
        subject
        expect(JSON.parse(response.body)).to eq(expected_error_hash)
      end
    end

    shared_examples 'successful response' do
      let(:expected_status) { :ok }

      it 'returns an ok status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'returns the expected mockdata' do
        subject
        mock_data = JSON.parse(response.body)['mock_profiles']
        expect(mock_data).to eq(expected_mock_data.with_indifferent_access)
      end

      it 'returns an encoded_credential that equals the credential payload' do
        subject
        JSON.parse(response.body)['mock_profiles'].each do |id, profile|
          expect(profile['encoded_credential']).to eq(expected_mock_data[id]['encoded_credential'])
        end
      end
    end

    context 'parameter validations' do
      context 'when CSP type parameter is missing' do
        let(:credential_type) { nil }
        let(:expected_error_message) { 'Invalid credential provider type' }

        it_behaves_like 'error response'
      end

      context 'when CSP type parameter is not included in CSP_TYPES' do
        let(:credential_type) { 'some-csp-type' }
        let(:expected_error_message) { 'Invalid credential provider type' }

        it_behaves_like 'error response'
      end

      context 'when CSP type parameter is included in CSP_TYPES' do
        it_behaves_like 'successful response'
      end
    end
  end

  describe 'GET index' do
    subject { get(index_path, params: index_params) }

    let(:index_path) { '/mocked_authentication/profiles' }
    let(:index_params) { { type: credential_type, state: passed_state } }
    let(:credential_type) { 'logingov' }
    let(:passed_state) { 'some-state' }

    shared_examples 'error response' do
      let(:expected_status) { :bad_request }
      let(:expected_error_hash) { { 'errors' => expected_error_message } }

      it 'returns expected status' do
        subject
        expect(response).to have_http_status(expected_status)
      end
    end

    shared_examples 'successful response' do
      let(:expected_status) { :ok }
      let(:html_title) { '<title>VA.gov | Mocked Authentication</title>' }

      it 'returns expected status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'returns expected html' do
        subject
        expect(response.body).to include(html_title)
      end
    end

    context 'parameter validations' do
      context 'when CSP type parameter is missing' do
        let(:credential_type) { nil }
        let(:expected_error_message) { 'Invalid credential provider type' }

        it_behaves_like 'error response'
      end

      context 'when CSP type parameter is not included in CSP_TYPES' do
        let(:credential_type) { 'some-csp-type' }
        let(:expected_error_message) { 'Invalid credential provider type' }

        it_behaves_like 'error response'
      end

      context 'when CSP type parameter is included in CSP_TYPES' do
        let(:credential_type) { 'logingov' }

        context 'and state is not defined' do
          let(:passed_state) { {} }
          let(:expected_error_message) { 'State is not defined' }

          it_behaves_like 'error response'
        end

        context 'and state parameter is included' do
          it_behaves_like 'successful response'
        end
      end
    end
  end
end
