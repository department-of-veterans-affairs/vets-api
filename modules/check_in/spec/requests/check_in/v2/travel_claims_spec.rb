# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CheckIn::V2::TravelClaims', type: :request do
  let(:id) { '5bcd636c-d4d3-4349-9058-03b2f6b38ced' }
  let(:claim_id) { 'a1178d06-ec2f-400c-fa9e-77e479fc5ef8' }
  let(:correlation_id) { 'correlation-123' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled').and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement')
                                        .and_return(true)

    Rails.cache.clear
  end

  describe 'POST `create`' do
    let(:post_params) do
      {
        travel_claims: {
          uuid: id,
          claim_id: claim_id,
          correlation_id: correlation_id
        }
      }
    end

    context 'when travel reimbursement feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement')
                                            .and_return(false)
      end

      it 'returns routing error' do
        post '/check_in/v2/travel_claims', params: post_params
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when session is not authorized' do
      let(:response_body) { { 'permissions' => 'read.none', 'status' => 'success', 'uuid' => id } }

      it 'returns unauthorized response' do
        post '/check_in/v2/travel_claims', params: post_params

        expect(response.body).to include('read.none')
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when session is authorized' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1950-01-27',
              last_name: 'Johnson'
            }
          }
        }
      end

      let(:mock_auth_manager) { instance_double(TravelClaim::AuthManager) }
      let(:mock_appointments_service) { instance_double(TravelClaim::AppointmentsService) }

      before do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          get "/check_in/v2/patient_check_ins/#{id}"
        end

        allow(TravelClaim::AuthManager).to receive(:new).and_return(mock_auth_manager)
        allow(TravelClaim::AppointmentsService).to receive(:new).and_return(mock_appointments_service)
      end

      context 'when claim submission is successful' do
        let(:successful_response) do
          {
            data: {
              'claimId' => claim_id,
              'status' => 'submitted',
              'submissionDate' => '2024-01-15T10:30:00Z'
            }
          }
        end

        before do
          allow(mock_appointments_service).to receive(:submit_claim_v3).and_return(successful_response)
        end

        it 'submits the claim and returns success response' do
          post '/check_in/v2/travel_claims', params: post_params

          expect(response).to have_http_status(:ok)
          
          response_data = JSON.parse(response.body)
          expect(response_data['data']['claimId']).to eq(claim_id)
          expect(response_data['data']['status']).to eq('submitted')
        end

        it 'calls the appointments service with correct parameters' do
          expect(mock_appointments_service).to receive(:submit_claim_v3).with(
            claim_id: claim_id,
            correlation_id: correlation_id
          ).and_return(successful_response)

          post '/check_in/v2/travel_claims', params: post_params
        end

        it 'generates correlation_id if not provided' do
          post_params[:travel_claims].delete(:correlation_id)
          
          allow(SecureRandom).to receive(:uuid).and_return('generated-uuid')
          expect(mock_appointments_service).to receive(:submit_claim_v3).with(
            claim_id: claim_id,
            correlation_id: 'generated-uuid'
          ).and_return(successful_response)

          post '/check_in/v2/travel_claims', params: post_params
        end
      end

      context 'when claim_id validation fails' do
        before do
          allow(mock_appointments_service).to receive(:submit_claim_v3)
            .and_raise(ArgumentError, 'Invalid claim ID provided (claim ID cannot be nil or empty).')
        end

        it 'returns bad request with validation error' do
          post '/check_in/v2/travel_claims', params: post_params

          expect(response).to have_http_status(:bad_request)
          
          response_data = JSON.parse(response.body)
          expect(response_data['error']).to include('Invalid claim ID')
        end
      end

      context 'when API call fails with BackendServiceException' do
        before do
          allow(mock_appointments_service).to receive(:submit_claim_v3)
            .and_raise(Common::Exceptions::BackendServiceException, 'API call failed')
        end

        it 'returns unprocessable entity with generic error message' do
          post '/check_in/v2/travel_claims', params: post_params

          expect(response).to have_http_status(:unprocessable_entity)
          
          response_data = JSON.parse(response.body)
          expect(response_data['error']).to eq('Travel claim submission failed')
        end
      end

      context 'when unexpected error occurs' do
        before do
          allow(mock_appointments_service).to receive(:submit_claim_v3)
            .and_raise(StandardError, 'Unexpected error')
        end

        it 'returns internal server error' do
          post '/check_in/v2/travel_claims', params: post_params

          expect(response).to have_http_status(:internal_server_error)
          
          response_data = JSON.parse(response.body)
          expect(response_data['error']).to eq('Internal server error')
        end
      end

      context 'when required parameters are missing' do
        it 'returns internal server error when claim_id is missing' do
          post_params[:travel_claims].delete(:claim_id)
          
          post '/check_in/v2/travel_claims', params: post_params
          
          expect(response).to have_http_status(:internal_server_error)
        end

        it 'returns unauthorized when uuid is missing' do
          post_params[:travel_claims].delete(:uuid)
          
          post '/check_in/v2/travel_claims', params: post_params
          
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
