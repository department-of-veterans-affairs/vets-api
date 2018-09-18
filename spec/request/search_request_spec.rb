# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'search', type: :request do
  include SchemaMatchers
  include ErrorDetails

  describe 'GET /v0/search' do
    context 'with a 200 response' do
      it 'should match the search schema', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', { query: 'benefits' }

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('search')
        end
      end

      it 'should return an array of hash search results in its body', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', { query: 'benefits' }

          body    = JSON.parse response.body
          results = body.dig('data', 'attributes', 'body', 'web', 'results')
          result  = results.first

          expect(results.class).to eq Array
          expect(result.class).to eq Hash
          expect(result.keys).to contain_exactly 'title', 'url', 'snippet', 'publication_date'
        end
      end
    end
  end
end
