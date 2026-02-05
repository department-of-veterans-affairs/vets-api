# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'base_accredited_representatives_controller_shared_examples' do |path, type|
  context 'when find a rep is disabled' do
    before do
      Flipper.disable(:find_a_representative_enable_api) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    it 'returns a not found routing error' do
      get path

      parsed_response = JSON.parse(response.body)

      expect(parsed_response['errors'].size).to eq(1)
      expect(parsed_response['errors'][0]['status']).to eq('404')
      expect(parsed_response['errors'][0]['title']).to eq('Not found')
      expect(parsed_response['errors'][0]['detail']).to eq('There are no routes matching your request: ')
    end
  end

  context 'when find a rep is enabled' do
    before do
      Flipper.enable(:find_a_representative_enable_api) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    context 'when a required param is missing' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Missing parameter')
        expect(parsed_response['errors'][0]['detail']).to eq('The required parameter "long", is missing')
      end
    end

    context 'when the type param is invalid' do
      it 'returns a bad request error' do
        get path, params: { type: 'abc', lat: 39, long: -75 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "type"')
      end
    end

    context 'when the sort param is invalid' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39, long: -75, sort: 'abc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "sort"')
      end
    end

    context 'when the sort param does not match the request type' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39, long: -75, sort: 'name_asc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"name_asc" is not a valid value for "sort"')
      end
    end

    context 'when lat is not a number' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 'abc', long: -75 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "lat"')
      end
    end

    context 'when lat is not in the allowed range' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 90.01, long: -75 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"90.01" is not a valid value for "lat"')
      end
    end

    context 'when long is not a number' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39, long: 'abc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "long"')
      end
    end

    context 'when long is not in the allowed range' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39, long: -180.01 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"-180.01" is not a valid value for "long"')
      end
    end

    context 'when distance can not be converted to an integer' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39, long: 77, distance: 'abc' }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"abc" is not a valid value for "distance"')
      end
    end

    context 'when distance is not one of the allowed values' do
      it 'returns a bad request error' do
        get path, params: { type:, lat: 39, long: 77, distance: 42 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['errors'].size).to eq(1)
        expect(parsed_response['errors'][0]['status']).to eq('400')
        expect(parsed_response['errors'][0]['title']).to eq('Invalid field value')
        expect(parsed_response['errors'][0]['detail']).to eq('"42" is not a valid value for "distance"')
      end
    end

    context 'when there are no results for the search criteria' do
      it 'returns an empty list' do
        get path, params: { type:, lat: 40.7128, long: -74.0060, distance: 50 }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['data']).to eq([])
        expect(parsed_response['meta']['pagination']['total_entries']).to eq(0)
      end
    end

    it 'returns ok for a successful request' do
      get path,
          params: { type:, lat: 40.7128, long: -74.0060 }

      expect(response).to have_http_status(:ok)
    end
  end
end
