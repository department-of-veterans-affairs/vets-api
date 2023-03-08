# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mocked Authentication Credential Providers', type: :request do
  describe '#authorize' do
    let(:path) { '/mocked_authentication/authorize' }
    let(:csp_type) { 'logingov' }
    let(:params) { URI.encode_www_form_component({ type: csp_type }.to_json) }

    context 'successful validations' do
      it 'returns an ok status' do
        get("#{path}?credential_info=#{params}")
        expect(response).to have_http_status(:ok)
      end

      it 'creates a new MockCredentialInfo' do
        expect_any_instance_of(MockedAuthentication::MockCredentialInfo).to receive(:save!)
        get("#{path}?credential_info=#{params}")
      end

      it 'returns a credential_info_code' do
        get("#{path}?credential_info=#{params}")
        expect(JSON.parse(response.body)['credential_info_code']).not_to be_empty
      end
    end

    context 'failed validations' do
      context 'missing CSP type' do
        let(:expected_error) { 'CSP type required' }
        let(:csp_type) { '' }

        it 'returns a bad_request status' do
          get("#{path}?credential_info=#{params}")
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns an error message' do
          get("#{path}?credential_info=#{params}")
          expect(JSON.parse(response.body)['errors']).to eq(expected_error)
        end
      end

      context 'invalid CSP type' do
        let(:expected_error) { 'Invalid CSP Type' }
        let(:csp_type) { 'bad_csp' }

        it 'returns a bad_request status' do
          get("#{path}?credential_info=#{params}")
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns an error message' do
          get("#{path}?credential_info=#{params}")
          expect(JSON.parse(response.body)['errors']).to eq(expected_error)
        end
      end
    end
  end
end
