# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'
require 'uri'

describe 'search_typeahead' do
  include ErrorDetails

  describe 'GET /v0/search_typeahead' do
    context 'on a successful get' do
      it 'has an array of responses', :aggregate_failures do
        VCR.use_cassette('search_typeahead/success') do
          get '/v0/search_typeahead', params: { query: 'ebenefits' }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to match_array [
            'ebenefits direct deposit',
            'ebenefits disability compensation',
            'ebenefits update contact information',
            'ebenefits your records',
            'ebenefits'
          ]
        end
      end
    end

    context 'with an empty query' do
      it 'has an empty response body', :aggregate_failures do
        VCR.use_cassette('search_typeahead/missing_query') do
          get '/v0/search_typeahead', params: { query: '' }

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq ''
        end
      end
    end
  end
end
