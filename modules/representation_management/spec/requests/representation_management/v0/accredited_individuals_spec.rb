# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::AccreditedIndividuals', type: :request do
  let(:path) { '/representation_management/v0/accredited_individuals' }
  let(:type) { 'representative' }
  let(:distance) { 50 }
  let(:lat) { 38.9072 }
  let(:long) { -77.0369 }

  context 'when find_a_representative_use_accredited_models is disabled' do
    before do
      Flipper.disable(:find_a_representative_use_accredited_models) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    it 'returns a not found routing error' do
      get path, params: { type:, lat:, long:, distance: }

      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors'].size).to eq(1)
      expect(parsed_response['errors'][0]['status']).to eq('404')
      expect(parsed_response['errors'][0]['title']).to eq('Not found')
      expect(parsed_response['errors'][0]['detail']).to eq('There are no routes matching your request: ')
    end
  end

  context 'when find_a_representative_use_accredited_models is enabled' do
    before do
      Flipper.enable(:find_a_representative_use_accredited_models) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    context 'when a required param is missing' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Missing parameter')
        expect(parsed_response['errors'][0]['detail']).to eq('The required parameter "long", is missing')
      end
    end

    context 'when the search is invalid' do
      it 'returns a list of the errors and an unprocessable entity error' do
        get path, params: { type: 'abc', lat:, long: -200, distance: 45 }

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'].size).to eq(3)
        expect(parsed_response['errors'][0]).to eq('Distance is not included in the list')
        expect(parsed_response['errors'][1]).to eq('Long must be greater than or equal to -180')
        expect(parsed_response['errors'][2]).to eq('Type is not included in the list')
      end
    end

    context 'when the search is valid' do
      let!(:ind1) do
        create(:accredited_individual,
               :with_organizations, registration_number: '12300', individual_type: 'representative',
                                    long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                                    first_name: 'Bob', last_name: 'Law') # ~6 miles from Washington, D.C.
      end
      let!(:ind2) do
        create(:accredited_individual,
               :with_organizations, registration_number: '23400', individual_type: 'representative',
                                    long: -77.436649, lat: 39.101481, location: 'POINT(-77.436649 39.101481)',
                                    first_name: 'Eliseo', last_name: 'Schroeder') # ~25 miles from Washington, D.C.
      end
      let!(:ind3) do
        create(:accredited_individual,
               :with_organizations, registration_number: '34500', individual_type: 'representative',
                                    long: -76.609383, lat: 39.299236, location: 'POINT(-76.609383 39.299236)',
                                    first_name: 'Marci', last_name: 'Weissnat') # ~35 miles from Washington, D.C.
      end
      let!(:ind4) do
        create(:accredited_individual,
               :with_organizations, registration_number: '45600', individual_type: 'representative',
                                    long: -77.466316, lat: 38.309875, location: 'POINT(-77.466316 38.309875)',
                                    first_name: 'Gerard', last_name: 'Ortiz') # ~47 miles from Washington, D.C.
      end
      let!(:ind5) do
        create(:accredited_individual,
               :with_organizations, registration_number: '56700', individual_type: 'representative',
                                    long: -76.3483, lat: 39.5359, location: 'POINT(-76.3483 39.5359)',
                                    first_name: 'Adriane', last_name: 'Crona') # ~57 miles from Washington, D.C.
      end
      let!(:ind6) do
        create(:accredited_individual,
               :with_organizations, registration_number: '67800', individual_type: 'representative',
                                    long: -76.3483, lat: 39.5359, location: 'POINT(-76.3483 39.5359)',
                                    first_name: 'Bob', last_name: 'Lawperson') # ~57 miles from Washington, D.C.
      end
      let!(:ind7) do
        create(:accredited_individual,
               :with_organizations, registration_number: '78900', individual_type: 'representative',
                                    first_name: 'No', last_name: 'Location') # no location
      end
      let!(:ind8) do
        create(:accredited_individual, registration_number: '89100', individual_type: 'attorney',
                                       long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                                       first_name: 'Joe', last_name: 'Lawyer') # ~6 miles from Washington, D.C.
      end

      it 'returns ok for a successful request' do
        get path, params: { type: 'attorney', lat:, long: }

        expect(response).to have_http_status(:ok)
      end

      it 'does not include accredited individuals outside of max distance' do
        get path, params: { type:, lat:, long:, distance: }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to contain_exactly(ind1.id, ind2.id, ind3.id, ind4.id)
      end

      it 'includes all accredited individuals of the specified type when distance is not provided' do
        get path, params: { type:, lat:, long:, distance: nil }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to contain_exactly(ind1.id, ind2.id, ind3.id, ind4.id, ind5.id,
                                                                       ind6.id)
      end

      it 'sorts by distance_asc by default' do
        get path, params: { type:, lat:, long:, distance: }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind1.id, ind2.id, ind3.id, ind4.id])
      end

      it 'can sort by first_name_asc' do
        get path, params: { type:, lat:, long:, distance:, sort: 'first_name_asc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind1.id, ind2.id, ind4.id, ind3.id])
      end

      it 'can sort by first_name_desc' do
        get path, params: { type:, lat:, long:, distance:, sort: 'first_name_desc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind3.id, ind4.id, ind2.id, ind1.id])
      end

      it 'can sort by last_name_asc' do
        get path, params: { type:, lat:, long:, distance:, sort: 'last_name_asc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind1.id, ind4.id, ind2.id, ind3.id])
      end

      it 'can sort by last_name_desc' do
        get path, params: { type:, lat:, long:, distance:, sort: 'last_name_desc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind3.id, ind2.id, ind4.id, ind1.id])
      end

      it 'can fuzzy search on name' do
        get path, params: { type:, lat:, long:, distance:, name: 'Bob Law' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind1.id])
      end

      it 'serializes the individual, organizations, and distance' do
        get path, params: { type:, lat:, long:, distance:, name: 'Bob Law' }

        parsed_response = JSON.parse(response.body)
        organizations = parsed_response['data'][0]['attributes']['accredited_organizations']
        poa_code = organizations['data'][0]['attributes']['poa_code']

        expect(parsed_response['data'][0]['attributes']['registration_number']).to eq('12300')
        expect(poa_code).not_to be_nil
        expect(parsed_response['data'][0]['attributes']['distance']).to be_within(0.05).of(6.0292)
      end

      it 'can search for non-representatives' do
        get path, params: { type: 'attorney', lat:, long:, distance: }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind8.id])
      end

      it 'paginates' do
        get path, params: { type:, lat:, long:, distance:, page: 1, per_page: 2 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind1.id, ind2.id])
        expect(parsed_response['meta']['pagination']['current_page']).to eq(1)
        expect(parsed_response['meta']['pagination']['per_page']).to eq(2)
        expect(parsed_response['meta']['pagination']['total_pages']).to eq(2)
        expect(parsed_response['meta']['pagination']['total_entries']).to eq(4)
      end

      context 'when there are no results for the search criteria' do
        it 'returns an empty list' do
          get path, params: { type: 'claims_agent', lat:, long: }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['data']).to eq([])
          expect(parsed_response['meta']['pagination']['total_entries']).to eq(0)
        end
      end
    end

    context 'when the type matches a Veteran::Service::Representative type' do
      let!(:ind1) do
        create(:accredited_individual, :with_location, individual_type: 'claims_agent')
      end

      it 'returns accredited individuals of the corresponding type' do
        # The type 'claim_agents' is from Veteran::Service::Representative
        # but it should map to the individual_type 'claims_agent' in AccreditedIndividual.
        get path, params: { type: 'claim_agents', lat:, long: }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq([ind1.id])
        expect(parsed_response['data'][0]['attributes']['individual_type']).to eq('claims_agent')
      end
    end
  end
end
