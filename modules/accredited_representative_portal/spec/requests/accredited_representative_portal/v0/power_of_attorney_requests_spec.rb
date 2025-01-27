# frozen_string_literal: true

require_relative '../../../rails_helper'

def load_response_fixture(path_suffix)
  dir = './power_of_attorney_requests_spec/responses'
  File.expand_path("#{dir}/#{path_suffix}", __dir__)
      .then { |path| File.read(path) }
      .then { |json| JSON.parse(json) }
end

dependent_claimant_power_of_attorney_form =
  load_response_fixture('dependent_claimant_power_of_attorney_form.json')

veteran_claimant_power_of_attorney_form =
  load_response_fixture('veteran_claimant_power_of_attorney_form.json')

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user, email: 'test@va.gov') }
  let(:poa_request) do
    resolution =
      create(
        :power_of_attorney_request_resolution,
        :declination,
        :with_veteran_claimant
      )

    resolution.power_of_attorney_request
  end
  let(:time) { '2024-12-21T04:45:37.000Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37.000Z' }
  let(:expires_at) { '2025-02-19T04:45:37.000Z' }

  let(:poa_requests) do
    [].tap do |memo|
      memo <<
        create(
          :power_of_attorney_request,
          :with_veteran_claimant
        )

      resolution_a =
        create(
          :power_of_attorney_request_resolution,
          :acceptance,
          :with_dependent_claimant
        )

      resolution_b =
        create(
          :power_of_attorney_request_resolution,
          :declination,
          :with_dependent_claimant
        )

      resolution_c =
        create(
          :power_of_attorney_request_resolution,
          :expiration,
          :with_dependent_claimant
        )

      memo << resolution_a.power_of_attorney_request
      memo << resolution_b.power_of_attorney_request
      memo << resolution_c.power_of_attorney_request
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
          {
            'id' => poa_requests[0].id,
            'claimant_id' => poa_requests[0].claimant_id,
            'created_at' => time,
            'expires_at' => (Time.zone.parse(time) + 60.days).iso8601(3),
            'power_of_attorney_form' => veteran_claimant_power_of_attorney_form,
            'power_of_attorney_holder' => {
              'id' => poa_requests[0].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[0].power_of_attorney_holder.name
            },
            'resolution' => nil
          },
          {
            'id' => poa_requests[1].id,
            'claimant_id' => poa_requests[1].claimant_id,
            'created_at' => time,
            'expires_at' => nil,
            'power_of_attorney_form' => dependent_claimant_power_of_attorney_form,
            'power_of_attorney_holder' => {
              'id' => poa_requests[1].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[1].power_of_attorney_holder.name
            },
            'resolution' => {
              'id' => poa_requests[1].resolution.id,
              'type' => 'decision',
              'created_at' => time,
              'creator_id' => poa_requests[1].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          },
          {
            'id' => poa_requests[2].id,
            'claimant_id' => poa_requests[2].claimant_id,
            'created_at' => time,
            'expires_at' => nil,
            'power_of_attorney_form' => dependent_claimant_power_of_attorney_form,
            'power_of_attorney_holder' => {
              'id' => poa_requests[2].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[2].power_of_attorney_holder.name
            },
            'resolution' => {
              'id' => poa_requests[2].resolution.id,
              'type' => 'decision',
              'created_at' => time,
              'creator_id' => poa_requests[2].resolution.resolving.creator_id,
              'reason' => 'Didn\'t authorize treatment record disclosure',
              'decision_type' => 'declination'
            }
          },
          {
            'id' => poa_requests[3].id,
            'claimant_id' => poa_requests[3].claimant_id,
            'created_at' => time,
            'expires_at' => nil,
            'power_of_attorney_form' => dependent_claimant_power_of_attorney_form,
            'power_of_attorney_holder' => {
              'id' => poa_requests[3].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[3].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[3].accredited_individual.id,
              'full_name' => [
                poa_requests[3].accredited_individual.first_name,
                poa_requests[3].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[3].resolution.id,
              'type' => 'expiration',
              'created_at' => time
            }
          }
        ]
      )
    end

    context 'when providing a status param' do
      let!(:pending_request1) { create(:power_of_attorney_request, created_at: time) }
      let!(:pending_request2) { create(:power_of_attorney_request, created_at: time_plus_one_day) }
      let!(:declined_request) { create(:power_of_attorney_request, :with_declination, resolution_created_at: time) }
      let!(:accepted_request) do
        create(:power_of_attorney_request, :with_acceptance, resolution_created_at: time_plus_one_day)
      end
      let!(:expired_request) do
        create(:power_of_attorney_request, :with_expiration, resolution_created_at: time_plus_one_day)
      end

      it 'returns the list of pending power of attorney requests sorted by creation date ascending' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=pending')
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response.length).to eq 2
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(declined_request.id)
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(accepted_request.id)
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(expired_request.id)
        expect(parsed_response.map { |h| h['created_at'] }).to eq([time, time_plus_one_day])
      end

      it 'returns the list of completed power of attorney requests sorted by resolution creation descending' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=processed')
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response.length).to eq 2
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(pending_request1.id)
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(pending_request2.id)
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(expired_request.id)
        expect(parsed_response.map { |h| h['resolution']['created_at'] }).to eq([time_plus_one_day, time])
      end

      it 'throws an error if any other status filter provided' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=invalid_status')
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    let(:poa_request) { create(:power_of_attorney_request, :with_declination) }
    let(:power_of_attorney_form) do
      poa_request.power_of_attorney_form.parsed_data.tap do |data|
        data.delete('dependent')
        data['claimant'] = data.delete('veteran')
      end
    end

    it 'returns the details of a specific power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq(
        {
          'id' => poa_request.id,
          'claimant_id' => poa_request.claimant_id,
          'created_at' => time,
          'expires_at' => nil,
          'power_of_attorney_form' => power_of_attorney_form,
          'resolution' => {
            'id' => poa_request.resolution.id,
            'type' => 'decision',
            'created_at' => time,
            'creator_id' => poa_request.resolution.resolving.creator_id,
            'reason' => 'Didn\'t authorize treatment record disclosure',
            'decision_type' => 'declination'
          },
          'power_of_attorney_holder' => {
            'id' => poa_request.power_of_attorney_holder.id,
            'type' => 'veteran_service_organization',
            'name' => 'TODO: implement'
          }
        }
      )
    end
  end
end
