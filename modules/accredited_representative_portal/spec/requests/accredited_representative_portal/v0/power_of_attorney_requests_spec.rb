# frozen_string_literal: true

require_relative '../../../rails_helper'
require_relative './support/poa_requests_responses'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user, email: 'test@va.gov') }
  let(:poa_request) { create(:power_of_attorney_request, :with_declination) }
  let(:time) { '2024-12-21T04:45:37Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37Z' }
  let(:expires_at) { '2025-02-19T04:45:37.000Z' }

  let(:poa_requests) do
    [].tap do |memo|
      memo << create(:power_of_attorney_request, skip_resolution: true)
      memo << create(:power_of_attorney_request, :with_acceptance)
      memo << create(:power_of_attorney_request, :with_acceptance, :with_veteran_type_form,
                     created_at: time_plus_one_day)
      memo << create(:power_of_attorney_request, :with_declination)
      memo << create(:power_of_attorney_request, :with_expiration)
    end
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of power of attorney requests' do
      poa_requests

      get('/accredited_representative_portal/v0/power_of_attorney_requests')

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq(
        [
          PoaRequestResponses.pending_poa_response(poa_requests[0], time, expires_at),
          PoaRequestResponses.accepted_poa_response(poa_requests[1], time),
          PoaRequestResponses.veteran_poa_response_with_extra_day(poa_requests[2], time, time_plus_one_day),
          PoaRequestResponses.declined_poa_response(poa_requests[3], time),
          PoaRequestResponses.expired_poa_response(poa_requests[4], time)

        ]
      )
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a specific power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq(
        PoaRequestResponses.declined_poa_response(poa_request, time)
      )
    end
  end
end
