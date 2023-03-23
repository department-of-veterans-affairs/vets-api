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
end
