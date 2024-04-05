# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:representative_user) { create(:representative_user) }

  before do
    login_as(representative_user)
    allow(Flipper).to receive(:enabled?).with(:accredited_representative_portal_api).and_return(true)
  end

  describe 'POST /accept' do
    it 'returns a successful response with an accepted message' do
      proc_id = '123'
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{proc_id}/accept"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Accepted')
    end
  end

  describe 'POST /decline' do
    it 'returns a successful response with an accepted message' do
      proc_id = '123'
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{proc_id}/decline"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Declined')
    end
  end

  describe 'GET /index' do
    context 'when valid POA codes are provided' do
      it 'returns a successful response with matching POA requests' do
        get '/accredited_representative_portal/v0/power_of_attorney_requests', params: { poa_codes: '091,A1Q' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['records']).to be_an_instance_of(Array)
        expect(json['records_count']).to be_an_instance_of(Integer)
      end
    end

    context 'when no POA codes are provided' do
      it 'returns a bad request status' do
        get '/accredited_representative_portal/v0/power_of_attorney_requests'
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('POA codes are required')
      end
    end

    context 'when POA codes parameter is empty' do
      it 'returns a bad request status' do
        get '/accredited_representative_portal/v0/power_of_attorney_requests', params: { poa_codes: '' }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('POA codes are required')
      end
    end

    context 'when there are no records for the provided POA' do
      it 'returns an empty records array' do
        get '/accredited_representative_portal/v0/power_of_attorney_requests', params: { poa_codes: 'XYZ,ABC' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['records']).to be_an_instance_of(Array)
        expect(json['records']).to be_empty
        expect(json['records_count']).to eq(0)
      end
    end
  end
end
