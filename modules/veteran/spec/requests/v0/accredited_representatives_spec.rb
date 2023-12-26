# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Find a Rep - Accredited Representatives spec', type: :request do
  context 'when find a rep is disabled' do
    before do
      Flipper.disable(:find_a_rep)
    end

    it 'returns a not found routing error' do
      get '/services/veteran/v0/accredited_representatives'

      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors'].size).to eq(1)
      expect(parsed_response['errors'][0]['status']).to eq('404')
      expect(parsed_response['errors'][0]['title']).to eq('Not found')
      expect(parsed_response['errors'][0]['detail']).to eq('There are no routes matching your request: ')
    end
  end

  context 'when find a rep is enabled' do
    before do
      Flipper.enable(:find_a_rep)
    end

    context 'when a required param is missing' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives', params: { type: 'organization', lat: 39 }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Missing parameter')
        expect(parsed_response['errors'][0]['detail']).to eq('The required parameter "long", is missing')
      end
    end

    context 'when the type param is invalid' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives', params: { type: 'abc', lat: 39, long: -75 }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "type"')
      end
    end

    context 'when the sort param is invalid' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 39, long: -75, sort: 'abc' }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "sort"')
      end
    end

    context 'when the sort param does not match the request type' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 39, long: -75, sort: 'name_asc' }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"name_asc" is not a valid value for "sort"')
      end
    end

    context 'when lat is not a number' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 'abc', long: -75 }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "lat"')
      end
    end

    context 'when lat is not in the allowed range' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 90.01, long: -75 }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"90.01" is not a valid value for "lat"')
      end
    end

    context 'when long is not a number' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 39, long: 'abc' }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "long"')
      end
    end

    context 'when long is not in the allowed range' do
      it 'returns a bad request error' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 39, long: -180.01 }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"-180.01" is not a valid value for "long"')
      end
    end

    context 'when there are no results for the search criteria' do
      it 'returns an empty list' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 40.7128, long: -74.0060 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data']).to eq([])
        expect(parsed_response['meta']['pagination']['total_entries']).to eq(0)
      end
    end

    it 'returns ok for a successful request' do
      get '/services/veteran/v0/accredited_representatives',
          params: { type: 'attorney', lat: 40.7128, long: -74.0060 }

      expect(response).to have_http_status(:ok)
    end

    context 'when searching for a representative' do
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
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).not_to include('567')
      end

      it 'sorts by distance_asc by default' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[123 234 345 456])
      end

      it 'can sort by first_name_asc' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, sort: 'first_name_asc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[123 234 456 345])
      end

      it 'can sort by first_name_desc' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, sort: 'first_name_desc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[345 456 234 123])
      end

      it 'can sort by last_name_asc' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, sort: 'last_name_asc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[123 456 234 345])
      end

      it 'can sort by last_name_desc' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, sort: 'last_name_desc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[345 234 456 123])
      end

      it 'can sort fuzzy search on name' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, name: 'Bob Law' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[123])
      end

      it 'serializes with the correct model and distance' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, name: 'Bob Law' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'][0]['attributes']['full_name']).to eq('Bob Law')
        expect(parsed_response['data'][0]['attributes']['distance']).to be_within(0.05).of(6.0292)
      end

      it 'paginates' do
        get '/services/veteran/v0/accredited_representatives',
            params: { type: 'attorney', lat: 38.9072, long: -77.0369, page: 1, per_page: 2 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data'].pluck('id')).to eq(%w[123 234])
        expect(parsed_response['meta']['pagination']['current_page']).to eq(1)
        expect(parsed_response['meta']['pagination']['per_page']).to eq(2)
        expect(parsed_response['meta']['pagination']['total_pages']).to eq(2)
        expect(parsed_response['meta']['pagination']['total_entries']).to eq(4)
      end
    end
  end
end
