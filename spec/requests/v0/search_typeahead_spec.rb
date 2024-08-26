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
  end
end
