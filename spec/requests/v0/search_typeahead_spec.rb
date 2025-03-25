# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'
require 'uri'

Rspec.describe 'V0::SearchTypeahead', type: :request do
  include ErrorDetails

  describe 'GET /v0/search_typeahead' do
    context 'on a successful get' do
      it 'has an array of responses', :aggregate_failures do
        VCR.use_cassette('search_typeahead/success') do
          get '/v0/search_typeahead', params: { query: 'ebenefits' }

          expect(response).to have_http_status(:ok)
          # rubocop:disable Layout/LineLength
          expect(response.body).to include '["ebenefits direct deposit","ebenefits disability compensation","ebenefits update contact information","ebenefits your records","ebenefits"]'
          # rubocop:enable Layout/LineLength
        end
      end
    end

    context 'with an empty string query' do
      it 'has an empty response body', :aggregate_failures do
        VCR.use_cassette('search_typeahead/missing_query') do
          get '/v0/search_typeahead', params: { query: '' }

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq ''
        end
      end

      it 'has an null response body', :aggregate_failures do
        VCR.use_cassette('search_typeahead/missing_query') do
          get '/v0/search_typeahead', params: { query: nil }
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq ''
        end
      end
    end

    context 'when a timeout error occurs' do
      before do
        allow_any_instance_of(SearchTypeahead::Service).to receive(:suggestions).and_return(
          OpenStruct.new(body: { error: 'The request timed out. Please try again.' }.to_json, status: 504)
        )
      end

      it 'returns a 504 status with a timeout error message' do
        get '/v0/search_typeahead', params: { query: 'ebenefits' }
        expect(response).to have_http_status(:gateway_timeout)
        parsed = JSON.parse(response.body)
        expect(parsed['error']).to eq 'The request timed out. Please try again.'
      end
    end

    context 'when a connection error occurs' do
      before do
        allow_any_instance_of(SearchTypeahead::Service).to receive(:suggestions).and_return(
          OpenStruct.new(body: { error: 'Unable to connect to the search service. Please try again later.' }.to_json,
                         status: 502)
        )
      end

      it 'returns a 502 status with a connection error message' do
        get '/v0/search_typeahead', params: { query: 'ebenefits' }
        expect(response).to have_http_status(:bad_gateway)
        parsed = JSON.parse(response.body)
        expect(parsed['error']).to eq 'Unable to connect to the search service. Please try again later.'
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow_any_instance_of(SearchTypeahead::Service).to receive(:suggestions).and_return(
          OpenStruct.new(body: { error: 'An unexpected error occurred.' }.to_json, status: 500)
        )
      end

      it 'returns a 500 status with an unexpected error message' do
        get '/v0/search_typeahead', params: { query: 'ebenefits' }
        expect(response).to have_http_status(:internal_server_error)
        parsed = JSON.parse(response.body)
        expect(parsed['error']).to eq 'An unexpected error occurred.'
      end
    end
  end
end
