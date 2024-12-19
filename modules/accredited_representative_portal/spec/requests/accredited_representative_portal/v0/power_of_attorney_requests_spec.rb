# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request) { create(:power_of_attorney_request) }
  let(:poa_requests) { create_list(:power_of_attorney_request, 3) }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of power of attorney requests' do
      poa_requests

      get('/accredited_representative_portal/v0/power_of_attorney_requests')

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)

      expected_response = AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer
                          .new(poa_requests)
                          .serializable_hash

      expect(parsed_response.to_json).to eq(expected_response.to_json)
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a specific power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)

      expected_response = AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer
                          .new(poa_request)
                          .serializable_hash

      expect(parsed_response.to_json).to eq(expected_response.to_json)
    end
  end
end
