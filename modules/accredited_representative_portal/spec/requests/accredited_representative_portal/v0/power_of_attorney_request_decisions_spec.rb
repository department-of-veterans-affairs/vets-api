# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let!(:poa_code) { 'x23' }

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

  let!(:vso) do
    create(:organization, poa: poa_code)
  end

  let(:time) { '2024-12-21T04:45:37.458Z' }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    context 'with invalid params' do
      it 'complains about an invalid type param' do
        poa_request = create(:power_of_attorney_request, poa_code: poa_code)

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'invalid_type', reason: nil } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(
          ['Type is not included in the list']
        )
      end

      it 'complains about an invalid reason param' do
        poa_request = create(:power_of_attorney_request, poa_code: poa_code)

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: 'not allowed to give reasons for these' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(
          ['Reason must be blank']
        )
      end
    end

    it 'creates acceptance decision with proper params' do
      poa_request = create(:power_of_attorney_request, poa_code: poa_code)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution.present?).to be(true)
      expect(poa_request.resolution.resolving.present?).to be(true)
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')
    end

    it 'creates declination decision with proper params' do
      poa_request = create(:power_of_attorney_request, poa_code: poa_code)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'declination', reason: 'bad data' } }

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution.present?).to be(true)
      expect(poa_request.resolution.resolving.present?).to be(true)
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestDeclination')
    end

    it 'returns an error if request does not exist' do
      post '/accredited_representative_portal/v0/power_of_attorney_requests/a/decision'

      expect(response).to have_http_status(:not_found)
      expect(parsed_response['errors']).to include(
        a_string_including("Couldn't find AccreditedRepresentativePortal::PowerOfAttorneyRequest with 'id'=a")
      )
    end

    it 'returns an error if decision already exists' do
      poa_request = create(:power_of_attorney_request, poa_code: poa_code)
      create(:power_of_attorney_request_resolution, :expiration,
             power_of_attorney_request: poa_request)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'declination', reason: 'bad data' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response['errors']).to eq(
        ['Power of attorney request has already been taken']
      )
    end
  end

  describe 'full cycle for decision api' do
    it 'returns the correct results for POST GET POST GET' do
      poa_request = create(:power_of_attorney_request, poa_code: poa_code)

      # --------------
      # GET REQUEST
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']).to be_nil

      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution.present?).to be(true)
      expect(poa_request.resolution.resolving.present?).to be(true)
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')

      # --------------
      # GET REQUEST
      resolution = poa_request.reload.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']['id']).to eq(resolution.id)

      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response['errors']).to eq(
        ['Power of attorney request has already been taken']
      )
    end
  end
end
