# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MapServices', type: :request do
  describe 'POST /v0/map_services/token' do
    subject(:call_endpoint) do
      post v0_map_services_token_path(application:), headers: service_account_auth_header
    end

    context 'when MAP STS client is not configured for use by the service account' do
      let(:application) { 'foobar' }

      include_context 'with service account authentication', 'foobar', ['http://www.example.com/v0/map_services/foobar/token'], { user_attributes: { icn: 42 } }

      it 'responds with error details in response body' do
        call_endpoint
        expect(JSON.parse(response.body)).to eq(
          {
            'error' => 'invalid_request',
            'error_description' => 'Application mismatch detected.'
          }
        )
      end

      it 'returns HTTP status bad_request' do
        call_endpoint
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when MAP STS client is configured for use by the service account' do
      let(:application) { 'chatbot' }

      context 'when service account access token does not have a user_attributes claim with ICN' do
        include_context 'with service account authentication', 'chatbot', ['http://www.example.com/v0/map_services/chatbot/token']

        it 'responds with error details in response body' do
          call_endpoint
          expect(JSON.parse(response.body)).to eq(
            {
              'error' => 'invalid_request',
              'error_description' => 'Service account access token does not contain an ICN in `user_attributes` claim.'
            }
          )
        end

        it 'returns HTTP status bad_request' do
          call_endpoint
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'when service account access token contains user_attributes claim with ICN' do
        include_context 'with service account authentication', 'chatbot', ['http://www.example.com/v0/map_services/chatbot/token'], { user_attributes: { icn: 42 } }

        context 'when MAP STS client raises a client error',
                vcr: { cassette_name: 'map/security_token_service_401_response' } do
          it 'responds with error details in response body' do
            call_endpoint
            expect(JSON.parse(response.body)).to eq(
              {
                'error' => 'server_error',
                'error_description' => 'STS failed to return a valid token.'
              }
            )
          end

          it 'returns HTTP status bad_gateway' do
            call_endpoint
            expect(response).to have_http_status(:bad_gateway)
          end
        end

        context 'when MAP STS client raises a gateway timeout error' do
          before do
            stub_request(:post, 'https://veteran.apps-staging.va.gov/sts/oauth/v1/token').to_raise(Net::ReadTimeout)
          end

          it 'responds with error details in response body' do
            call_endpoint
            expect(JSON.parse(response.body)).to eq(
              {
                'error' => 'server_error',
                'error_description' => 'STS failed to return a valid token.'
              }
            )
          end

          it 'returns HTTP status bad_gateway' do
            call_endpoint
            expect(response).to have_http_status(:bad_gateway)
          end
        end

        context 'when MAP STS client returns an invalid token',
                vcr: { cassette_name: 'map/security_token_service_200_invalid_token' } do
          it 'responds with error details in response body' do
            call_endpoint
            expect(JSON.parse(response.body)).to eq(
              {
                'error' => 'server_error',
                'error_description' => 'STS failed to return a valid token.'
              }
            )
          end

          it 'returns HTTP status bad_gateway' do
            call_endpoint
            expect(response).to have_http_status(:bad_gateway)
          end
        end

        context 'when MAP STS client returns a valid access token',
                vcr: { cassette_name: 'map/security_token_service_200_response' } do
          it 'responds with STS-issued token in response body' do
            call_endpoint
            expect(JSON.parse(response.body)).to include('access_token' => anything, 'expiration' => anything)
          end

          it 'returns HTTP status ok' do
            call_endpoint
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end
