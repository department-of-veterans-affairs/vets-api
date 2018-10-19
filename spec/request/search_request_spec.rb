# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

describe 'search', type: :request do
  include SchemaMatchers
  include ErrorDetails

  describe 'GET /v0/search' do
    context 'with a 200 response' do
      it 'should match the search schema', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', query: 'benefits'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('search')
        end
      end

      it 'should return an array of hash search results in its body', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', query: 'benefits'

          body    = JSON.parse response.body
          results = body.dig('data', 'attributes', 'body', 'web', 'results')
          result  = results.first

          expect(results.class).to eq Array
          expect(result.class).to eq Hash
          expect(result.keys).to contain_exactly 'title', 'url', 'snippet', 'publication_date'
        end
      end
    end

    context 'with an empty query string' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('search/empty_query') do
          get '/v0/search', query: ''

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with un-sanitized parameters' do
      it 'sanitizes the input, stripping all tags and attributes that are not whitelisted' do
        VCR.use_cassette('search/success') do
          dirty_params     = '<script>alert(document.cookie);</script>'
          sanitized_params = 'alert(document.cookie);'

          expect(Search::Service).to receive(:new).with(sanitized_params, '20')

          get '/v0/search', query: dirty_params, offset: 20
        end
      end
    end

    context 'with pagination' do
      let(:query_term) { 'test' }

      context "the endpoint's response" do
        it 'should return pagination offsets for previous and next page results', :aggregate_failures do
          VCR.use_cassette('search/offset_40') do
            get '/v0/search', query: query_term, offset: 40

            pagination = pagination_for(response)

            expect(pagination['next']).to be_present
            expect(pagination['previous']).to be_present
          end
        end

        context 'on the first page of the search results' do
          it 'previous should be null', :aggregate_failures do
            VCR.use_cassette('search/offset_0') do
              get '/v0/search', query: query_term, offset: 0

              pagination = pagination_for(response)

              expect(pagination.keys).to include 'previous'
              expect(pagination['previous']).to_not be_present
              expect(pagination['next']).to be_present
            end
          end
        end

        context 'on the last page of the search results' do
          it 'next should be null', :aggregate_failures do
            VCR.use_cassette('search/offset_60') do
              get '/v0/search', query: query_term, offset: 60

              pagination = pagination_for(response)

              expect(pagination.keys).to include 'next'
              expect(pagination['next']).to_not be_present
              expect(pagination['previous']).to be_present
            end
          end
        end
      end

      context 'when the endpoint is being called' do
        context 'with an offset' do
          it 'should pass the offset request to the search service object' do
            expect(Search::Service).to receive(:new).with(query_term, '20')

            get '/v0/search', query: query_term, offset: 20
          end
        end

        context 'with no offset present' do
          it 'should pass offset=nil to the search service object' do
            expect(Search::Service).to receive(:new).with(query_term, nil)

            get '/v0/search', query: query_term
          end
        end
      end
    end
  end
end

def pagination_for(response)
  body = JSON.parse response.body

  body.dig('data', 'attributes', 'body', 'pagination')
end
