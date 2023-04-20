# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/client'

RSpec.describe 'Covid Vaccine Facilities', type: :request do
  include SchemaMatchers

  let(:zip) { '60607' }
  let(:non_existent_zip) { '02020' }

  let(:expected_response_attributes) do
    %w[name distance city state]
  end

  describe '#index' do
    context 'for a valid query' do
      around do |example|
        VCR.use_cassette('covid_vaccine/facilities/query_60607',
                         match_requests_on: %i[method path], &example)
      end

      it 'returns successfully' do
        get "/covid_vaccine/v0/facilities/#{zip}"
        expect(response).to have_http_status(:ok)
      end

      it 'returns a list of facilities' do
        get "/covid_vaccine/v0/facilities/#{zip}"
        body = JSON.parse(response.body)
        expect(body['data'].length).to eq(5)
      end

      it 'returns elements with expected attributes' do
        get "/covid_vaccine/v0/facilities/#{zip}"
        body = JSON.parse(response.body)
        first = body['data'].first
        expect(first['attributes']).to include(*expected_response_attributes)
      end

      context 'with count parameter' do
        it 'returns the requested result count' do
          get "/covid_vaccine/v0/facilities/#{zip}", params: { count: '3' }
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq(3)
        end

        it 'ignores zero values' do
          get "/covid_vaccine/v0/facilities/#{zip}", params: { count: '0' }
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq(5)
        end

        it 'ignores invalid values' do
          get "/covid_vaccine/v0/facilities/#{zip}", params: { count: 'foo' }
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq(5)
        end

        it 'ignores too-large values' do
          get "/covid_vaccine/v0/facilities/#{zip}", params: { count: '100' }
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq(5)
        end
      end
    end

    context 'for a non-existent zip' do
      around do |example|
        VCR.use_cassette('covid_vaccine/facilities/query_02020',
                         match_requests_on: %i[method path], &example)
      end

      it 'returns a 4xx error' do
        get "/covid_vaccine/v0/facilities/#{non_existent_zip}"
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with any error from the facilities API' do
      it 'returns an empty list' do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities)
          .and_raise(StandardError.new('facilities exception'))
        get "/covid_vaccine/v0/facilities/#{zip}"
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
