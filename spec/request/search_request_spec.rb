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
          get '/v0/search', params: { query: 'benefits' }

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('search')
        end
      end

      it 'should return an array of hash search results in its body', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', params: { query: 'benefits' }

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
          get '/v0/search', params: { query: '' }

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

          expect(Search::Service).to receive(:new).with(sanitized_params, '2')

          get '/v0/search', params: { query: dirty_params, page: 2 }
        end
      end
    end

    context 'with pagination' do
      let(:query_term) { 'benefits' }

      context "the endpoint's response" do
        it 'should return pagination meta data', :aggregate_failures do
          VCR.use_cassette('search/page_1') do
            get '/v0/search', params: { query: query_term, page: 1 }

            pagination = pagination_for(response)

            expect(pagination['current_page']).to be_present
            expect(pagination['per_page']).to be_present
            expect(pagination['total_pages']).to be_present
            expect(pagination['total_entries']).to be_present
          end
        end

        context 'when a specific page number is requested' do
          it 'current_page should be equal to the requested page number' do
            VCR.use_cassette('search/page_2') do
              get '/v0/search', params: { query: query_term, page: 2 }

              pagination = pagination_for(response)

              expect(pagination['current_page']).to eq 2
            end
          end
        end
      end

      context 'when the endpoint is being called' do
        context 'with a page' do
          it 'should pass the page request to the search service object' do
            expect(Search::Service).to receive(:new).with(query_term, '2')

            get '/v0/search', params: { query: query_term, page: 2 }
          end
        end

        context 'with no page present' do
          it 'should pass page=nil to the search service object' do
            expect(Search::Service).to receive(:new).with(query_term, nil)

            get '/v0/search', params: { query: query_term }
          end
        end
      end
    end
  end
end

def pagination_for(response)
  body = JSON.parse response.body

  body.dig('meta', 'pagination')
end
