# frozen_string_literal: true

require 'rails_helper'
require_relative 'accredited_representatives_shared_spec'

RSpec.describe 'OtherAccreditedRepresentativesController', type: :request do
  include_examples 'base_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/other_accredited_representatives', 'attorney'

  include_examples 'base_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/other_accredited_representatives', 'claims_agents'

  context 'when searching for an attorney' do
    let(:path) { '/services/veteran/v0/other_accredited_representatives' }
    let(:type) { 'attorney' }

    before do
      create(:representative, representative_id: '123', poa_codes: ['A12'], user_types: ['attorney'],
                              long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                              first_name: 'Bob', last_name: 'Law') # ~6 miles from Washington, D.C.

      create(:representative, representative_id: '999', poa_codes: ['A12'], user_types: ['claim_agents'],
                              long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                              first_name: 'Bobby', last_name: 'Low') # ~6 miles from Washington, D.C.

      create(:representative, representative_id: '234', poa_codes: ['A12'], user_types: ['attorney'],
                              long: -77.436649, lat: 39.101481, location: 'POINT(-77.436649 39.101481)',
                              first_name: 'Eliseo', last_name: 'Schroeder') # ~25 miles from Washington, D.C.

      create(:representative, representative_id: '345', poa_codes: ['A12'], user_types: ['attorney'],
                              long: -76.609383, lat: 39.299236, location: 'POINT(-76.609383 39.299236)',
                              first_name: 'Marci', last_name: 'Weissnat') # ~35 miles from Washington, D.C.

      create(:representative, representative_id: '456', poa_codes: ['A12'], user_types: ['attorney'],
                              long: -77.466316, lat: 38.309875, location: 'POINT(-77.466316 38.309875)',
                              first_name: 'Gerard', last_name: 'Ortiz') # ~47 miles from Washington, D.C.

      create(:representative, representative_id: '567', poa_codes: ['A12'], user_types: ['attorney'],
                              long: -76.3483, lat: 39.5359, location: 'POINT(-76.3483 39.5359)',
                              first_name: 'Adriane', last_name: 'Crona') # ~57 miles from Washington, D.C.
    end

    it 'does not include representatives outside of max distance' do
      get path, params: { type:, lat: 38.9072, long: -77.0369 }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).not_to include('567')
    end

    it 'sorts by distance_asc by default' do
      get path, params: { type:, lat: 38.9072, long: -77.0369 }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 234 345 456])
    end

    it 'can sort by first_name_asc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'first_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 234 456 345])
    end

    it 'can sort by first_name_desc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'first_name_desc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[345 456 234 123])
    end

    it 'can sort by last_name_asc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'last_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 456 234 345])
    end

    it 'can sort by last_name_desc' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, sort: 'last_name_desc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[345 234 456 123])
    end

    it 'can fuzzy search on name' do
      get path, params: { type:, lat: 38.9072, long: -77.0369, name: 'Bob Law' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123])
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

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 234])
      expect(parsed_response['meta']['pagination']['current_page']).to eq(1)
      expect(parsed_response['meta']['pagination']['per_page']).to eq(2)
      expect(parsed_response['meta']['pagination']['total_pages']).to eq(2)
      expect(parsed_response['meta']['pagination']['total_entries']).to eq(4)
    end
  end
end
