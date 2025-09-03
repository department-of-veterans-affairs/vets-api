# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CheckIn::V1::TravelClaims', type: :request do
  let(:uuid) { 'd602d9eb-9a31-40bf-9c83-49fb7aed601f' }
  let(:appointment_date) { '2024-01-01T12:00:00Z' }
  let(:facility_type) { 'oh' }
  let(:check_in_session) { instance_double(CheckIn::V2::Session) }
  let(:service) { instance_double(TravelClaim::ClaimSubmissionService) }
  let(:low_auth_token) { 'low-auth-token' }

  before do
    allow(CheckIn::V2::Session).to receive(:build).and_return(check_in_session)
    allow(check_in_session).to receive(:authorized?).and_return(true)
    allow(TravelClaim::ClaimSubmissionService).to receive(:new).and_return(service)
    allow(service).to receive(:submit_claim).and_return({ 'success' => true, 'claimId' => 'claim-456' })
    allow_any_instance_of(CheckIn::V1::TravelClaimsController).to receive(:low_auth_token).and_return(low_auth_token)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement').and_return(true)
  end

  describe 'POST /check_in/v1/travel_claims' do
    let(:valid_params) do
      {
        travel_claims: {
          uuid:,
          appointment_date:,
          facility_type:
        }
      }
    end

    context 'when feature flag is enabled' do
      context 'with valid parameters and authorized user' do
        it 'returns success response' do
          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          expect(json_response).to include('success' => true)
          expect(json_response).to include('claimId' => 'claim-456')
        end

        it 'creates check-in session with correct parameters' do
          expect(CheckIn::V2::Session).to receive(:build).with(
            data: { uuid: },
            jwt: low_auth_token
          ).and_return(check_in_session)

          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }
        end

        it 'builds claim submission service with correct parameters' do
          expect(TravelClaim::ClaimSubmissionService).to receive(:new).with(
            check_in: check_in_session,
            appointment_date:,
            facility_type:,
            uuid:
          ).and_return(service)

          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }
        end

        it 'calls submit_claim on the service' do
          expect(service).to receive(:submit_claim).and_return({ 'success' => true, 'claimId' => 'claim-456' })

          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }
        end
      end

      context 'when user is not authorized' do
        before do
          allow(check_in_session).to receive_messages(
            authorized?: false,
            unauthorized_message: {
              permissions: 'read.none',
              status: 'success',
              uuid:
            }
          )
        end

        it 'returns unauthorized status' do
          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }

          expect(response).to have_http_status(:unauthorized)
        end

        it 'returns unauthorized message' do
          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }

          json_response = JSON.parse(response.body)
          expect(json_response).to include('permissions' => 'read.none')
          expect(json_response).to include('status' => 'success')
          expect(json_response).to include('uuid' => uuid)
        end
      end

      context 'with invalid parameters' do
        context 'when travel_claims key is missing' do
          let(:invalid_params) do
            {
              uuid:,
              appointment_date:,
              facility_type:
            }
          end

          it 'returns internal server error status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:internal_server_error)
          end

          it 'returns error message about missing travel_claims key' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            json_response = JSON.parse(response.body)
            expect(json_response).to include('success' => false)
            expect(json_response).to include('errors')
            expect(json_response['errors']).to be_present
          end
        end

        context 'when required parameters are missing from travel_claims' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid:
                # missing appointment_date and facility_type
              }
            }
          end

          before do
            allow(service).to receive(:submit_claim).and_raise(
              Common::Exceptions::BackendServiceException.new('VA900', { detail: 'Appointment date is required' }, 502)
            )
          end

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end

          it 'returns validation errors' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            json_response = JSON.parse(response.body)
            expect(json_response).to include('success' => false)
            expect(json_response).to include('errors')
          end
        end

        context 'when parameters are empty strings' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid: '',
                appointment_date: '',
                facility_type: ''
              }
            }
          end

          before do
            allow(service).to receive(:submit_claim).and_raise(
              Common::Exceptions::BackendServiceException.new('VA900', { detail: 'Uuid is required' }, 502)
            )
          end

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end
        end

        context 'when parameters are nil' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid: nil,
                appointment_date: nil,
                facility_type: nil
              }
            }
          end

          before do
            allow(service).to receive(:submit_claim).and_raise(
              Common::Exceptions::BackendServiceException.new('VA900', { detail: 'Uuid is required' }, 502)
            )
          end

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end
        end

        context 'when appointment_date is not ISO format' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid:,
                appointment_date: '2024-01-01', # Missing time component
                facility_type:
              }
            }
          end

          before do
            allow(service).to receive(:submit_claim).and_raise(
              Common::Exceptions::BackendServiceException.new(
                'VA900',
                { detail: 'Missing required arguments: appointment date time' },
                502
              )
            )
          end

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end
        end

        context 'when facility_type is invalid' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid:,
                appointment_date:,
                facility_type: 'invalid_type'
              }
            }
          end

          before do
            allow(service).to receive(:submit_claim).and_raise(
              Common::Exceptions::BackendServiceException.new('VA900', { detail: 'Facility type is required' }, 502)
            )
          end

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when service raises an error' do
        before do
          allow(service).to receive(:submit_claim).and_raise(
            Common::Exceptions::BackendServiceException.new('VA900', { detail: 'Service error' }, 502)
          )
        end

        it 'returns bad request status' do
          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }

          expect(response).to have_http_status(:bad_request)
        end

        it 'returns error details' do
          post '/check_in/v1/travel_claims', params: valid_params,
                                             headers: { 'Authorization' => "Bearer #{low_auth_token}" }

          json_response = JSON.parse(response.body)
          expect(json_response).to include('success' => false)
          expect(json_response).to include('errors')
          expect(json_response['errors']).to be_present
        end
      end

      context 'when malformed JSON is sent' do
        it 'returns internal server error status' do
          post '/check_in/v1/travel_claims',
               params: '{"travel_claims": {"uuid": "invalid json',
               headers: { 'Authorization' => "Bearer #{low_auth_token}", 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement').and_return(false)
      end

      it 'returns not found status' do
        post '/check_in/v1/travel_claims', params: valid_params,
                                           headers: { 'Authorization' => "Bearer #{low_auth_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authorization header is missing' do
      before do
        allow(check_in_session).to receive_messages(
          authorized?: false,
          unauthorized_message: {
            permissions: 'read.none',
            status: 'success',
            uuid:
          }
        )
      end

      it 'returns unauthorized status' do
        post '/check_in/v1/travel_claims', params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authorization header is invalid' do
      before do
        allow(check_in_session).to receive_messages(
          authorized?: false,
          unauthorized_message: {
            permissions: 'read.none',
            status: 'success',
            uuid:
          }
        )
      end

      it 'returns unauthorized status' do
        post '/check_in/v1/travel_claims', params: valid_params, headers: { 'Authorization' => 'Bearer invalid-token' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
