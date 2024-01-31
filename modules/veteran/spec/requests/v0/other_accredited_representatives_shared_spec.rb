# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'other_accredited_representatives_controller_shared_examples' do |path, type|
  context "when searching for type '#{type}'" do
    it 'does not include results outside of the max distance' do
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
