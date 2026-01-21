# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V1::TravelClaimsController, type: :controller do
  routes { CheckIn::Engine.routes }
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
    allow(controller).to receive(:low_auth_token).and_return(low_auth_token)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement').and_return(true)

    # Set up Authorization header for the new validation
    request.headers['Authorization'] = "Bearer #{low_auth_token}"
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        travel_claims: {
          uuid:,
          appointment_date:,
          facility_type:
        }
      }
    end

    context 'when user is authorized' do
      it 'creates a check-in session' do
        post :create, params: valid_params
        expect(CheckIn::V2::Session).to have_received(:build).with(
          data: { uuid: },
          jwt: low_auth_token
        )
      end

      it 'builds the claim submission service' do
        post :create, params: valid_params
        expect(TravelClaim::ClaimSubmissionService).to have_received(:new).with(
          appointment_date:,
          facility_type:,
          check_in_uuid: uuid
        )
      end

      it 'calls submit_claim on the service' do
        post :create, params: valid_params
        expect(service).to have_received(:submit_claim)
      end

      it 'returns success response' do
        post :create, params: valid_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include('success' => true)
        expect(JSON.parse(response.body)).to include('claimId' => 'claim-456')
      end
    end

    context 'when user is not authorized' do
      before do
        allow(check_in_session).to receive_messages(authorized?: false,
                                                    unauthorized_message: {
                                                      permissions: 'read.none', status: 'success', uuid:
                                                    })
      end

      it 'returns unauthorized status' do
        post :create, params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized message' do
        post :create, params: valid_params
        expect(JSON.parse(response.body)).to include('permissions' => 'read.none')
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

        it 'returns bad request due to missing travel_claims key' do
          post :create, params: invalid_params
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors']).to be_present
        end
      end

      context 'when required parameters are missing from travel_claims' do
        let(:invalid_params) do
          {
            travel_claims: {
              uuid:
            }
          }
        end

        before do
          allow(service).to receive(:submit_claim).and_raise(
            Common::Exceptions::BackendServiceException.new('VA901',
                                                            { detail: 'Appointment date is required' }, 400)
          )
        end

        it 'returns bad request due to missing parameters' do
          post :create, params: invalid_params
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
