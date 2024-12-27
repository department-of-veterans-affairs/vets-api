# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request) { create(:power_of_attorney_request_resolution, :declination).power_of_attorney_request }
  let(:time) { '2024-12-21T04:45:37.458Z' }

  let(:poa_requests) do
    [].tap do |memo|
      memo << create(:power_of_attorney_request)
      memo << create(:power_of_attorney_request_resolution, :acceptance).power_of_attorney_request
      memo << create(:power_of_attorney_request_resolution, :declination).power_of_attorney_request
      memo << create(:power_of_attorney_request_resolution, :expiration).power_of_attorney_request
    end
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of power of attorney requests', skip: 'temp skip' do
      poa_requests

      get('/accredited_representative_portal/v0/power_of_attorney_requests')

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        'data' => [
          {
            'id' => poa_requests[0].id,
            'type' => 'power_of_attorney_request',
            'attributes' => {
              'claimant_id' => poa_requests[0].claimant_id,
              'created_at' => time,
              'resolution' => nil
            }
          },
          {
            'id' => poa_requests[1].id,
            'type' => 'power_of_attorney_request',
            'attributes' => {
              'claimant_id' => poa_requests[1].claimant_id,
              'created_at' => time,
              'resolution' => {
                'data' => {
                  'id' => poa_requests[1].resolution.id,
                  'type' => 'power_of_attorney_request_decision',
                  'attributes' => {
                    'created_at' => time,
                    'creator_id' => poa_requests[1].resolution.resolving.creator_id,
                    'decision_type' => 'acceptance'
                  }
                }
              }
            }
          },
          {
            'id' => poa_requests[2].id,
            'type' => 'power_of_attorney_request',
            'attributes' => {
              'claimant_id' => poa_requests[2].claimant_id,
              'created_at' => time,
              'resolution' => {
                'data' => {
                  'id' => poa_requests[2].resolution.id,
                  'type' => 'power_of_attorney_request_decision',
                  'attributes' => {
                    'created_at' => time,
                    'creator_id' => poa_requests[2].resolution.resolving.creator_id,
                    'reason' => 'Didn\'t authorize treatment record disclosure',
                    'decision_type' => 'declination'
                  }
                }
              }
            }
          },
          {
            'id' => poa_requests[3].id,
            'type' => 'power_of_attorney_request',
            'attributes' => {
              'claimant_id' => poa_requests[3].claimant_id,
              'created_at' => time,
              'resolution' => {
                'data' => {
                  'id' => poa_requests[3].resolution.id,
                  'type' => 'power_of_attorney_request_expiration',
                  'attributes' => {
                    'created_at' => time
                  }
                }
              }
            }
          }
        ]
      )
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a specific power of attorney request', skip: 'temp skip' do

      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        'data' => {
          'id' => poa_request.id,
          'type' => 'power_of_attorney_request',
          'attributes' => {
            'claimant_id' => poa_request.claimant_id,
            'created_at' => time,
            'resolution' => {
              'data' => {
                'id' => poa_request.resolution.id,
                'type' => 'power_of_attorney_request_decision',
                'attributes' => {
                  'created_at' => time,
                  'creator_id' => poa_request.resolution.resolving.creator_id,
                  'reason' => 'Didn\'t authorize treatment record disclosure',
                  'decision_type' => 'declination'
                }
              }
            }
          }
        }
      )
    end
  end
end
