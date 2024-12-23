# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request_details_id) { '123' }
  let(:poa_request_details_mock_data) do
    {
      'status' => 'Pending',
      'declinedReason' => nil,
      'powerOfAttorneyCode' => '091',
      'submittedAt' => '2024-04-30T11:03:17Z',
      'acceptedOrDeclinedAt' => nil,
      'isAddressChangingAuthorized' => false,
      'isTreatmentDisclosureAuthorized' => true,
      'veteran' => { 'firstName' => 'Jon', 'middleName' => nil, 'lastName' => 'Smith',
                     'participantId' => '6666666666666' },
      'representative' => { 'email' => 'j2@example.com', 'firstName' => 'Jane', 'lastName' => 'Doe' },
      'claimant' => { 'firstName' => 'Sam', 'lastName' => 'Smith', 'participantId' => '777777777777777',
                      'relationshipToVeteran' => 'Child' },
      'claimantAddress' => { 'city' => 'Hartford', 'state' => 'CT', 'zip' => '06107', 'country' => 'GU',
                             'militaryPostOffice' => nil, 'militaryPostalCode' => nil }
    }
  end
  let(:poa_request_list_mock_data) do
    [poa_request_details_mock_data, poa_request_details_mock_data, poa_request_details_mock_data]
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of a power of attorney request' do
      get('/accredited_representative_portal/v0/power_of_attorney_requests')
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(poa_request_list_mock_data)
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request_details_id}")
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(poa_request_details_mock_data)
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    it 'returns decision if exists' do
      request = FactoryBot.create(:power_of_attorney_request)
      resolution = FactoryBot.create(:power_of_attorney_request_resolution, :with_decision, power_of_attorney_request: request)

      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to eq("Approval")
      expect(response_body["id"]).to eq(resolution.resolving_id)
    end

    it 'returns request expiration if exists' do
      request = FactoryBot.create(:power_of_attorney_request)
      resolution = FactoryBot.create(:power_of_attorney_request_resolution, :with_expiration, power_of_attorney_request: request)

      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to be_nil
      expect(response_body["id"]).to eq(resolution.resolving_id)
    end

    it 'returns an error if no request exists' do
      get "/accredited_representative_portal/v0/power_of_attorney_requests/a/decision"

      expect(response).to have_http_status(:not_found)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Not Found')
    end

    it 'returns an error if no resolution exists' do
      request = FactoryBot.create(:power_of_attorney_request)
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:not_found)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Resolution Not Found')
    end

    it 'returns an error if no outcome exists' do
      request = FactoryBot.create(:power_of_attorney_request)
      resolution = FactoryBot.create(:power_of_attorney_request_resolution, :with_decision, power_of_attorney_request: request)
      AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.find(resolution.resolving_id).delete

      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:not_found)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Outcome Not Found')
    end
  end

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    it 'returns created accepted decision with proper proper params' do
      request = FactoryBot.create(:power_of_attorney_request)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision", params: {"decision": {"declination_reason": nil}}

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to eq("Approval")
      request.reload

      expect(response_body["id"]).to eq(request.resolution.resolving_id)
    end

    it 'returns created decline decision with proper proper params' do
      request = FactoryBot.create(:power_of_attorney_request)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision", params: {"decision": {"declination_reason": "bad data"}}

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to eq("Rejection")
      request.reload

      expect(response_body["id"]).to eq(request.resolution.resolving_id)
    end

    it 'retuns an error if request does not exist' do
      post "/accredited_representative_portal/v0/power_of_attorney_requests/a/decision"

      expect(response).to have_http_status(:not_found)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Not Found')
    end

    it 'returns an error if decision already exists' do
      request = FactoryBot.create(:power_of_attorney_request)
      resolution = FactoryBot.create(:power_of_attorney_request_resolution, :with_expiration, power_of_attorney_request: request)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Resolution already exists')
    end
  end

  describe "full cycle for decision api" do
    it "returns the correct results for POST GET POST GET" do
      request = FactoryBot.create(:power_of_attorney_request)

      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision", params: {"decision": {"declination_reason": nil}}

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to eq("Approval")
      request.reload

      expect(response_body["id"]).to eq(request.resolution.resolving_id)

      # --------------
      # GET REQUEST
      resolution = request.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to eq("Approval")
      expect(response_body["id"]).to eq(resolution.resolving_id)


      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['error']).to eq('Resolution already exists')

      # --------------
      # GET REQUEST
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["type"]).to eq("Approval")
      expect(response_body["id"]).to eq(resolution.resolving_id)
    end
  end
end
