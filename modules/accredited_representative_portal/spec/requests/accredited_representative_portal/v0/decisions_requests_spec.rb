# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::DecisionsController, type: :request do
    let(:test_user) { create(:representative_user) }  
    let(:time) { '2024-12-21T04:45:37.458Z' }

    before do
        Flipper.enable(:accredited_representative_portal_pilot)
        login_as(test_user)
        travel_to(time)
    end

    describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
        it 'returns decision if exists' do
          request = FactoryBot.create(:power_of_attorney_request)
          resolution = FactoryBot.create(:power_of_attorney_request_resolution, :acceptance, power_of_attorney_request: request)
    
          get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"
    
          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body["type"]).to eq("AccreditedRepresentativePortal::PowerOfAttorneyRequestAcceptance")
          expect(response_body["id"]).to eq(resolution.resolving_id)
        end
    
        it 'returns request expiration if exists' do
          request = FactoryBot.create(:power_of_attorney_request)
          resolution = FactoryBot.create(:power_of_attorney_request_resolution, :expiration, power_of_attorney_request: request)
    
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
          resolution = FactoryBot.create(:power_of_attorney_request_resolution, :acceptance, power_of_attorney_request: request)
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
          expect(response_body["type"]).to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE)
          request.reload
    
          expect(response_body["id"]).to eq(request.resolution.resolving_id)
        end
    
        it 'returns created decline decision with proper proper params' do
          request = FactoryBot.create(:power_of_attorney_request)
          post "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision", params: {"decision": {"declination_reason": "bad data"}}
    
          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body["type"]).to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION)
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
          resolution = FactoryBot.create(:power_of_attorney_request_resolution, :expiration, power_of_attorney_request: request)
    
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
          expect(response_body["type"]).to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE)
          request.reload
    
          expect(response_body["id"]).to eq(request.resolution.resolving_id)
    
          # --------------
          # GET REQUEST
          resolution = request.resolution
          get "/accredited_representative_portal/v0/power_of_attorney_requests/#{request.id}/decision"
    
          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body["type"]).to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE)
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
          expect(response_body["type"]).to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE)
          expect(response_body["id"]).to eq(resolution.resolving_id)
        end
    end
end
