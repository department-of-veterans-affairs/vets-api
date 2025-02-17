# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           poa_code: poa_code)
  end

  let!(:representative) do
    create(:representative,
           :vso,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let!(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let!(:poa_request) { create(:power_of_attorney_request, poa_code: poa_code) }
  let!(:other_poa_request) { create(:power_of_attorney_request, poa_code: other_poa_code) }

  let(:time) { '2024-12-21T04:45:37.458Z' }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    context 'when user’s VSO does not accept digital POAs' do
      before do
        vso.update!(can_accept_digital_poa_requests: false)
      end

      it 'returns 403 Forbidden' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      it 'complains about an invalid type param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'invalid_type', reason: nil } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(['Type is not included in the list'])
      end

      it 'complains about an invalid reason param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: 'not allowed to give reasons for these' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(['Reason must be blank'])
      end
    end

    context 'with valid params' do
      it 'creates an acceptance decision' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})
        poa_request.reload

        expect(poa_request.resolution).to be_present
        expect(poa_request.resolution.resolving).to be_present
        expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')
      end

      it 'creates a declination decision' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'declination', reason: 'bad data' } }

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})
        poa_request.reload

        expect(poa_request.resolution).to be_present
        expect(poa_request.resolution.resolving).to be_present
        expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestDeclination')
      end
    end

    context 'when request does not exist' do
      it 'returns 404 Not Found' do
        post '/accredited_representative_portal/v0/power_of_attorney_requests/nonexistent/decision'

        expect(response).to have_http_status(:not_found)
        expect(parsed_response['errors']).to include(
          a_string_including("Couldn't find AccreditedRepresentativePortal::PowerOfAttorneyRequest")
        )
      end
    end

    context 'when decision already exists' do
      before do
        create(:power_of_attorney_request_resolution, :expiration, power_of_attorney_request: poa_request)
      end

      it 'returns an error' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'declination', reason: 'bad data' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(['Power of attorney request has already been taken'])
      end
    end
  end

  describe 'Full decision cycle' do
    it 'handles a full POST GET POST GET workflow' do
      # GET request before decision
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"
      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']).to be_nil

      # POST request (create decision)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution).to be_present
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')

      # GET request after decision
      resolution = poa_request.reload.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']['id']).to eq(resolution.id)

      # Attempt to POST decision again (should fail)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response['errors']).to eq(['Power of attorney request has already been taken'])
    end
  end
end
