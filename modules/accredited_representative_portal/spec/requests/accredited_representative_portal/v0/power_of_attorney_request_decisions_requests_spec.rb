# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:time) { '2024-12-21T04:45:37.458Z' }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    it 'creates acceptance decision with proper params' do
      poa_request = FactoryBot.create(:power_of_attorney_request)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('Decision successfully created')
      poa_request.reload

      expect(poa_request.resolution.present?).to eq(true)
      expect(poa_request.resolution.resolving.present?).to eq(true)
      expect(poa_request.resolution.resolving.type).to eq('acceptance')
    end

    it 'creates declination decision with proper params' do
      poa_request = FactoryBot.create(:power_of_attorney_request)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'declination', reason: 'bad data' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('Decision successfully created')
      poa_request.reload

      expect(poa_request.resolution.present?).to eq(true)
      expect(poa_request.resolution.resolving.present?).to eq(true)
      expect(poa_request.resolution.resolving.type).to eq('declination')
    end

    it 'returns an error if request does not exist' do
      post '/accredited_representative_portal/v0/power_of_attorney_requests/a/decision'

      expect(response).to have_http_status(:not_found)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Not Found')
    end

    it 'returns an error if decision already exists' do
      poa_request = FactoryBot.create(:power_of_attorney_request)
      FactoryBot.create(:power_of_attorney_request_resolution, :expiration,
                        power_of_attorney_request: poa_request)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'declination', reason: 'bad data' } }

      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Failed to create decision')
    end
  end

  describe 'full cycle for decision api' do
    it 'returns the correct results for POST GET POST GET' do
      poa_request = FactoryBot.create(:power_of_attorney_request)

      # --------------
      # GET REQUEST
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body['resolution']).to be_nil

      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('Decision successfully created')
      poa_request.reload

      expect(poa_request.resolution.present?).to eq(true)
      expect(poa_request.resolution.resolving.present?).to eq(true)
      expect(poa_request.resolution.resolving.type).to eq('acceptance')

      # --------------
      # GET REQUEST
      resolution = poa_request.reload.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body['resolution']['id']).to eq(resolution.id)

      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Failed to create decision')
    end
  end
end
