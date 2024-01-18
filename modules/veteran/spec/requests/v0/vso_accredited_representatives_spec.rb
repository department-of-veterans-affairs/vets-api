# frozen_string_literal: true

require 'rails_helper'
require_relative 'accredited_representatives_shared_spec'

RSpec.describe 'VSOAccreditedRepresentativesController', type: :request do
  include_examples 'base_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/vso_accredited_representatives', 'veteran_service_officer'

  context 'when searching for a veteran service officer' do
    let(:path) { '/services/veteran/v0/vso_accredited_representatives' }
    let(:type) { 'veteran_service_officer' }

    before do
      Flipper.enable(:find_a_rep)
      # Create representatives
      create(:representative, representative_id: '111', poa_codes: %w[A12 A13], user_types: ['veteran_service_officer'],
                              long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                              first_name: 'Bob', last_name: 'Law') # ~6 miles from Washington, D.C.

      create(:representative, representative_id: '112', poa_codes: ['A13'], user_types: ['claim_agents'],
                              long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                              first_name: 'Bobby', last_name: 'Low') # ~6 miles from Washington, D.C.

      create(:representative, representative_id: '113', poa_codes: %w[A11 A12 A13], user_types: ['veteran_service_officer'], # rubocop:disable Layout/LineLength
                              long: -77.436649, lat: 39.101481, location: 'POINT(-77.436649 39.101481)',
                              first_name: 'Bobbie', last_name: 'Lew') # ~25 miles from Washington, D.C.

      create(:representative, representative_id: '114', poa_codes: %w[A12 A13], user_types: ['veteran_service_officer'],
                              long: -76.609383, lat: 39.299236, location: 'POINT(-76.609383 39.299236)',
                              first_name: 'Robert', last_name: 'Lanyard') # ~35 miles from Washington, D.C.

      create(:representative, representative_id: '115', poa_codes: ['A13'], user_types: ['veteran_service_officer'],
                              long: -77.466316, lat: 38.309875, location: 'POINT(-77.466316 38.309875)',
                              first_name: 'Gerard', last_name: 'Ortiz') # ~47 miles from Washington, D.C.

      create(:representative, representative_id: '116', poa_codes: ['A13'], user_types: ['veteran_service_officer'],
                              long: -76.3483, lat: 39.5359, location: 'POINT(-76.3483 39.5359)',
                              first_name: 'Adriane', last_name: 'Crona') # ~57 miles from Washington, D.C.

      # Create organizations
      create(:organization, poa: 'A10', long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                            name: 'Bob Law') # ~6 miles from Washington, D.C.

      create(:organization, poa: 'A11', long: -77.436649, lat: 39.101481, location: 'POINT(-77.436649 39.101481)',
                            name: 'Missouri Veterans Commission') # ~25 miles from Washington, D.C.

      create(:organization, poa: 'A12', long: -76.609383, lat: 39.299236, location: 'POINT(-76.609383 39.299236)',
                            name: 'Alabama Department of Veterans Affairs') # ~35 miles from Washington, D.C.

      create(:organization, poa: 'A13', long: -77.466316, lat: 38.309875, location: 'POINT(-77.466316 38.309875)',
                            name: 'Washington Department of Veterans Affairs') # ~47 miles from Washington, D.C.
    end

    it 'does not include veteran service officer outside of max distance' do
      get path, params: { type:, lat: 38.9072, long: -77.0369 }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).not_to include('116')
    end

    it 'sorts by distance_asc by default' do
      get path, params: { type:, lat: 38.9072, long: -77.0369 }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[111 113 114 115])
    end

    it 'can sort by first_name_asc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'first_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[111 113 115 114])
    end

    it 'can sort by first_name_desc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'first_name_desc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[114 115 113 111])
    end

    it 'can sort by last_name_asc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'last_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[114 111 113 115])
    end

    it 'can sort by last_name_desc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'last_name_desc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[115 113 111 114])
    end

    it 'returns an empty array when performing a fuzzy search on a non-existent name' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, name: 'No Name' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq([])
    end

    it "returns accurate results for fuzzy searches on a representative's name" do
      get path, params: { type:, lat: 38.9072, long: -77.0369, name: 'Bob Law' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[111 113])
    end

    it 'returns accurate results for fuzzy searches on organization names linked to representatives' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, name: 'Alabama dept' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[111 113 114])
    end

    it 'serializes with the correct model and distance' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, name: 'Bob Law' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'][0]['attributes']['full_name']).to eq('Bob Law')
      expect(parsed_response['data'][0]['attributes']['distance']).to be_within(0.05).of(6.0292)
    end

    it 'paginates' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, page: 1, per_page: 2 }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[111 113])
      expect(parsed_response['meta']['pagination']['current_page']).to eq(1)
      expect(parsed_response['meta']['pagination']['per_page']).to eq(2)
      expect(parsed_response['meta']['pagination']['total_pages']).to eq(2)
      expect(parsed_response['meta']['pagination']['total_entries']).to eq(4)
    end

    it 'returns a list of the organization names that each representative belongs to' do
      expected_organization_names = [
        ['Alabama Department of Veterans Affairs', 'Washington Department of Veterans Affairs'],
        ['Alabama Department of Veterans Affairs', 'Missouri Veterans Commission', 'Washington Department of Veterans Affairs'], # rubocop:disable Layout/LineLength
        ['Washington Department of Veterans Affairs'],
        ['Alabama Department of Veterans Affairs', 'Washington Department of Veterans Affairs']
      ]
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'first_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[111 113 115 114])

      parsed_response['data'].each_with_index do |data, index|
        expect(data['attributes']['organization_names']).to eq(expected_organization_names[index])
      end
    end
  end
end
