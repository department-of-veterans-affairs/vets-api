# frozen_string_literal: true

require_relative '../../../rails_helper'
require_relative './support/poa_requests_responses'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
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
    it 'returns the list of power of attorney requests and defaults to status pending' do
      poa_requests

      get('/accredited_representative_portal/v0/power_of_attorney_requests')

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          PoaRequestResponses.poa_response0(poa_requests, time, expires_at)
        ]
      )
    end

    it 'returns the list of accepted power of attorney requests and orders them correctly by poa_request.created_at' do
      poa_requests

      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: { status: 'accepted' }

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          PoaRequestResponses.poa_response_2_with_extra_day(poa_requests, time, time_plus_one_day),
          PoaRequestResponses.poa_response1(poa_requests, time)
        ]
      )
    end

    it 'returns the list of accepted power of attorney requests and orders them correctly by resolution.created_at' do
      poa_requests

      poa_requests[1].resolution.created_at = time_plus_one_day
      poa_requests[1].resolution.save

      get '/accredited_representative_portal/v0/power_of_attorney_requests',
          params: { status: 'accepted', sort_field: 'resolution.created_at', sort_direction: 'asc' }

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          PoaRequestResponses.poa_response_2_with_extra_day(poa_requests, time, time_plus_one_day),
          PoaRequestResponses.poa_response_1_with_resolution_extra_day(poa_requests, time, time_plus_one_day)
        ]
      )
    end

    it 'orders power of attorney requests correctly by resolution.created_at desc' do
      poa_requests

      poa_requests[2].resolution.created_at = time_plus_one_day
      poa_requests[2].resolution.save

      get '/accredited_representative_portal/v0/power_of_attorney_requests',
          params: { status: 'accepted', sort_field: 'resolution.created_at' }

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          PoaRequestResponses.poa_response_2_with_both_extra_day(poa_requests, time_plus_one_day),
          PoaRequestResponses.poa_response1(poa_requests, time)
        ]
      )
    end

    it 'returns paginated results' do
      poa_requests

      poa_requests[1].resolution.created_at = time_plus_one_day
      poa_requests[1].resolution.save

      get '/accredited_representative_portal/v0/power_of_attorney_requests',
          params: { status: 'accepted', sort_field: 'resolution.created_at', page_size: 1 }

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          PoaRequestResponses.poa_response_1_with_resolution_extra_day(poa_requests, time, time_plus_one_day)
        ]
      )
    end

    it 'returns an error when status is not valid' do
      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: { status: 'Not Real' }

      expect(response).to have_http_status(:bad_request)
      parsed_response = JSON.parse(response.body)

      expect(parsed_response).to eq(
        {
          'errors' => [
            {
              'field' => 'status',
              'message' => 'must be one of: pending, accepted, declined'
            }
          ]
        }
      )
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a specific power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        PoaRequestResponses.singular_poa_response(poa_request, time)
      )
    end
  end
end
