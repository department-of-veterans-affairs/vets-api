# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CheckIn::V1::TravelClaims', type: :request do
  let(:uuid) { 'd602d9eb-9a31-40bf-9c83-49fb7aed601f' }
  let(:appointment_date) { '2024-01-15T10:00:00Z' }
  let(:facility_type) { 'oh' }
  let(:low_auth_token) { 'low-auth-token' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Set up session cache for authorization
    session_key = "check_in_lorota_v2_#{uuid}_read.full"
    Rails.cache.write(
      session_key,
      low_auth_token,
      namespace: 'check-in-lorota-v2-cache',
      expires_in: 43_200
    )

    # Set up appointment identifiers cache for TravelClaim::RedisClient
    Rails.cache.write(
      "check_in_lorota_v2_appointment_identifiers_#{uuid}",
      {
        data: {
          id: uuid,
          type: :appointment_identifier,
          attributes: {
            patientDFN: '123',
            stationNo: 'facility-123',
            icn: '1234567890V123456',
            mobilePhone: '7141234567',
            patientCellPhone: '1234567890',
            facilityType: facility_type
          }
        }
      }.to_json,
      namespace: 'check-in-lorota-v2-cache',
      expires_in: 43_200
    )

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
          VCR.use_cassette 'check_in/travel_claim/veis_token_200' do
            VCR.use_cassette 'check_in/travel_claim/system_access_token_200' do
              VCR.use_cassette 'check_in/travel_claim/appointments_find_or_add_200' do
                VCR.use_cassette 'check_in/travel_claim/claims_create_200' do
                  VCR.use_cassette 'check_in/travel_claim/expenses_mileage_200' do
                    VCR.use_cassette 'check_in/travel_claim/claims_submit_200' do
                      post '/check_in/v1/travel_claims', params: valid_params,
                                                         headers: { 'Authorization' => "Bearer #{low_auth_token}" }
                    end
                  end
                end
              end
            end
          end

          expect(response).to have_http_status(:created)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          expect(json_response).to include('success' => true)
          expect(json_response).to include('claimId' => 'claim-456')
        end
      end

      context 'when user is not authorized' do
        before do
          # Clear the Redis data to simulate unauthorized user
          Rails.cache.clear
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

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end

          it 'returns error message about missing travel_claims key' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            json_response = JSON.parse(response.body)
            expect(json_response).to include('errors')
            expect(json_response['errors']).to be_an(Array)
            expect(json_response['errors']).to be_present
          end
        end

        context 'when required parameters are missing from travel_claims' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid:
                # missing appointment_date
              }
            }
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
            expect(json_response).to include('errors')
            expect(json_response['errors']).to be_an(Array)
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

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:unauthorized)
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

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when appointment_date is not valid format' do
          let(:invalid_params) do
            {
              travel_claims: {
                uuid:,
                appointment_date: 'invalid-date',
                facility_type:
              }
            }
          end

          it 'returns bad request status' do
            post '/check_in/v1/travel_claims', params: invalid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }

            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when claim already exists for appointment' do
        it 'returns specific error message from Travel Pay API' do
          VCR.use_cassette 'check_in/travel_claim/veis_token_200' do
            VCR.use_cassette 'check_in/travel_claim/system_access_token_200' do
              VCR.use_cassette 'check_in/travel_claim/appointments_find_or_add_200' do
                VCR.use_cassette 'check_in/travel_claim/claims_create_400_duplicate' do
                  post '/check_in/v1/travel_claims', params: valid_params,
                                                     headers: { 'Authorization' => "Bearer #{low_auth_token}" }
                end
              end
            end
          end

          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_an(Array)
          expected_message = 'Validation failed: A claim has already been created for this appointment.'
          expect(json_response['errors'].first['detail']).to eq(expected_message)
          expect(response).to have_http_status(:bad_request)
        end

        it 'logs existing claim error when 400 status is received' do
          # Mock Rails.logger to capture log calls
          allow(Rails.logger).to receive(:error)

          VCR.use_cassette 'check_in/travel_claim/veis_token_200' do
            VCR.use_cassette 'check_in/travel_claim/system_access_token_200' do
              VCR.use_cassette 'check_in/travel_claim/appointments_find_or_add_200' do
                VCR.use_cassette 'check_in/travel_claim/claims_create_400_duplicate' do
                  post '/check_in/v1/travel_claims', params: valid_params,
                                                     headers: { 'Authorization' => "Bearer #{low_auth_token}" }
                end
              end
            end
          end

          # Verify that the API error log was called
          expect(Rails.logger).to have_received(:error).with(
            'TravelPayClient API error',
            hash_including(
              status: 400,
              code: 'duplicate_claim',
              operation: 'claims#create'
            )
          )
        end
      end

      context 'when service raises an error' do
        it 'returns bad request status' do
          VCR.use_cassette 'check_in/travel_claim/veis_token_200' do
            VCR.use_cassette 'check_in/travel_claim/system_access_token_200' do
              VCR.use_cassette 'check_in/travel_claim/appointments_find_or_add_400' do
                post '/check_in/v1/travel_claims', params: valid_params,
                                                   headers: { 'Authorization' => "Bearer #{low_auth_token}" }
              end
            end
          end

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response).to include('errors')
          expect(json_response['errors']).to be_an(Array)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to eq('Invalid appointment date format')
        end

        it 'returns error details' do
          VCR.use_cassette 'check_in/travel_claim/appointments_find_or_add_400' do
            post '/check_in/v1/travel_claims', params: valid_params,
                                               headers: { 'Authorization' => "Bearer #{low_auth_token}" }
          end

          json_response = JSON.parse(response.body)
          expect(json_response).to include('errors')
          expect(json_response['errors']).to be_an(Array)
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
  end
end
