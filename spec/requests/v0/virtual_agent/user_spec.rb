# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::VirtualAgentUser', type: :request do
  describe 'GET /v0/virtual_agent/user' do
    subject(:call_endpoint) do
      get v0_virtual_agent_user_path, headers: service_account_auth_header, params:
    end

    let(:params) { { code: } }
    let(:code) { 'some-code' }
    let(:icn) { 'some-icn' }

    before { create(:chatbot_code_container, code:, icn:) }

    context 'when code matches an existing code container' do
      include_context 'with service account authentication', 'chatbot', ['http://www.example.com/v0/virtual_agent/user'], { user_attributes: nil }

      let(:expected_response) { { icn: }.to_json }

      it 'responds with icn in response body' do
        call_endpoint
        expect(response.body).to eq(expected_response)
      end

      it 'returns HTTP status ok' do
        call_endpoint
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when code does not match an existing code container' do
      let(:params) { { code: 'some-invalid-code' } }
      let(:expected_response) { { error: 'invalid_request', error_description: 'Code is not valid.' }.to_json }

      include_context 'with service account authentication', 'chatbot', ['http://www.example.com/v0/virtual_agent/user'], { user_attributes: nil }

      it 'responds invalid code error' do
        call_endpoint
        expect(response.body).to eq(expected_response)
      end

      it 'returns HTTP status bad request' do
        call_endpoint
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when valid code has been used multiple times' do
      let(:expected_response) { { error: 'invalid_request', error_description: 'Code is not valid.' }.to_json }

      before { get v0_virtual_agent_user_path, headers: service_account_auth_header, params: }

      include_context 'with service account authentication', 'chatbot', ['http://www.example.com/v0/virtual_agent/user'], { user_attributes: nil }

      it 'responds invalid code error' do
        call_endpoint

        expect(response.body).to eq(expected_response)
      end

      it 'returns HTTP status bad request' do
        call_endpoint
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
