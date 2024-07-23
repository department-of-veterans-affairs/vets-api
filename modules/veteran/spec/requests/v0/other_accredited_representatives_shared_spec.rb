# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'other_accredited_representatives_controller_shared_examples' do |path, type|
  context "when searching for type '#{type}'" do
    let(:distance) { 50 }
    let(:lat) { 38.9072 }
    let(:long) { -77.0369 }

    context 'distance' do
      context 'when providing a max distance param' do
        it 'does not include results outside of the max distance' do
          get path, params: { type:, lat:, long:, distance: }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['data'].pluck('id')).not_to include('567')
          expect(parsed_response['data'].pluck('id')).to match_array(%w[123 234 345 456])
        end
      end

      context 'when no max distance param is provided' do
        it 'includes all reps with a location regardless of distance' do
          get path, params: { type:, lat:, long: }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['data'].pluck('id')).not_to include('935')
          expect(parsed_response['data'].pluck('id')).to match_array(%w[123 234 345 456 567])
        end
      end
    end

    it 'sorts by distance_asc by default' do
      get path, params: { type:, lat:, long:, distance: }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 234 345 456])
    end

    it 'can sort by first_name_asc' do
      get path, params: { type:, lat:, long:, distance:, sort: 'first_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 234 456 345])
    end

    it 'can sort by first_name_desc' do
      get path, params: { type:, lat:, long:, distance:, sort: 'first_name_desc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[345 456 234 123])
    end

    it 'can sort by last_name_asc' do
      get path, params: { type:, lat:, long:, distance:, sort: 'last_name_asc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 456 234 345])
    end

    it 'can sort by last_name_desc' do
      get path, params: { type:, lat:, long:, distance:, sort: 'last_name_desc' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[345 234 456 123])
    end

    it 'can fuzzy search on name' do
      get path, params: { type:, lat:, long:, distance:, name: 'Bob Law' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123])
    end

    it 'serializes with the correct model and distance' do
      get path, params: { type:, lat:, long:, distance:, name: 'Bob Law' }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'][0]['attributes']['full_name']).to eq('Bob Law')
      expect(parsed_response['data'][0]['attributes']['distance']).to be_within(0.05).of(6.0292)
    end

    it 'paginates' do
      get path, params: { type:, lat:, long:, distance:, page: 1, per_page: 2 }

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['data'].pluck('id')).to eq(%w[123 234])
      expect(parsed_response['meta']['pagination']['current_page']).to eq(1)
      expect(parsed_response['meta']['pagination']['per_page']).to eq(2)
      expect(parsed_response['meta']['pagination']['total_pages']).to eq(2)
      expect(parsed_response['meta']['pagination']['total_entries']).to eq(4)
    end
  end
end
