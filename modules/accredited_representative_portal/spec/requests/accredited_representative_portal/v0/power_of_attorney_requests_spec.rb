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
            'claimantId' => poa_requests[0].claimant_id,
            'createdAt' => time,
            'expiresAt' => (Time.zone.parse(time) + 60.days).iso8601(3),
            'powerOfAttorneyForm' => veteran_claimant_power_of_attorney_form,
            'powerOfAttorneyHolder' => {
              'id' => poa_requests[0].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[0].power_of_attorney_holder.name
            },
            'accreditedIndividual' => {
              'id' => poa_requests[0].accredited_individual.id,
              'fullName' => [
                poa_requests[0].accredited_individual.first_name,
                poa_requests[0].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => nil
          },
          {
            'id' => poa_requests[1].id,
            'claimantId' => poa_requests[1].claimant_id,
            'createdAt' => time,
            'expiresAt' => nil,
            'powerOfAttorneyForm' => dependent_claimant_power_of_attorney_form,
            'powerOfAttorneyHolder' => {
              'id' => poa_requests[1].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[1].power_of_attorney_holder.name
            },
            'accreditedIndividual' => {
              'id' => poa_requests[1].accredited_individual.id,
              'fullName' => [
                poa_requests[1].accredited_individual.first_name,
                poa_requests[1].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[1].resolution.id,
              'type' => 'decision',
              'createdAt' => time,
              'creatorId' => poa_requests[1].resolution.resolving.creator_id,
              'decisionType' => 'acceptance'
            }
          },
          {
            'id' => poa_requests[2].id,
            'claimantId' => poa_requests[2].claimant_id,
            'createdAt' => time,
            'expiresAt' => nil,
            'powerOfAttorneyForm' => dependent_claimant_power_of_attorney_form,
            'powerOfAttorneyHolder' => {
              'id' => poa_requests[2].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[2].power_of_attorney_holder.name
            },
            'accreditedIndividual' => {
              'id' => poa_requests[2].accredited_individual.id,
              'fullName' => [
                poa_requests[2].accredited_individual.first_name,
                poa_requests[2].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[2].resolution.id,
              'type' => 'decision',
              'createdAt' => time,
              'creatorId' => poa_requests[2].resolution.resolving.creator_id,
              'reason' => 'Didn\'t authorize treatment record disclosure',
              'decisionType' => 'declination'
            }
          },
          {
            'id' => poa_requests[3].id,
            'claimantId' => poa_requests[3].claimant_id,
            'createdAt' => time,
            'expiresAt' => nil,
            'powerOfAttorneyForm' => dependent_claimant_power_of_attorney_form,
            'powerOfAttorneyHolder' => {
              'id' => poa_requests[3].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[3].power_of_attorney_holder.name
            },
            'accreditedIndividual' => {
              'id' => poa_requests[3].accredited_individual.id,
              'fullName' => [
                poa_requests[3].accredited_individual.first_name,
                poa_requests[3].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[3].resolution.id,
              'type' => 'expiration',
              'createdAt' => time
            }
          }
        ]
      )
    end

    context 'when providing a status param' do
      let!(:declined_request) { create(:power_of_attorney_request, :with_declination) }
      let!(:pending_request) { create(:power_of_attorney_request) }

      it 'returns the list of pending power of attorney requests' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=pending')
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response.length).to eq 2
        expect(parsed_response.map { |poa| poa['id'] }).to include(pending_request.id)
        expect(parsed_response.map { |poa| poa['id'] }).not_to include(declined_request.id)
      end

      it 'returns the list of completed power of attorney requests' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=completed')
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response.length).to eq 1
        expect(parsed_response[0]['id']).to eq declined_request.id
      end

      it 'throws an error if any other status filter provided' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=delete_all')
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
          'claimantId' => poa_request.claimant_id,
          'createdAt' => time,
          'expiresAt' => nil,
          'powerOfAttorneyForm' => power_of_attorney_form,
          'resolution' => {
            'id' => poa_request.resolution.id,
            'type' => 'decision',
            'createdAt' => time,
            'creatorId' => poa_request.resolution.resolving.creator_id,
            'reason' => 'Didn\'t authorize treatment record disclosure',
            'decisionType' => 'declination'
          },
          'powerOfAttorneyHolder' => {
            'id' => poa_request.power_of_attorney_holder.id,
            'type' => 'veteran_service_organization',
            'name' => poa_request.power_of_attorney_holder.name
          },
          'accreditedIndividual' => {
            'id' => poa_request.accredited_individual.id,
            'fullName' => [
              poa_request.accredited_individual.first_name,
              poa_request.accredited_individual.last_name
            ].join(' ')
          }
        }
      )
    end
  end
end
