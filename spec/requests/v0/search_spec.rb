# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

Rspec.describe 'V0::Search', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    Flipper.disable(:search_use_v2_gsa) # rubocop:disable Project/ForbidFlipperToggleInSpecs
  end

  describe 'GET /v0/search' do
    context 'with a 200 response' do
      it 'matches the search schema', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', params: { query: 'benefits' }

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('search')
        end
      end

      it 'matches the search schema when camel-inflected', :aggregate_failures do
        VCR.use_cassette('search/success') do
          get '/v0/search', params: { query: 'benefits' }, headers: inflection_header

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('search')
        end
      end

      it 'returns an array of hash search results in its body', :aggregate_failures do
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
      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('search/empty_query') do
          get '/v0/search', params: { query: '' }

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        VCR.use_cassette('search/empty_query') do
          get '/v0/search', params: { query: '' }, headers: inflection_header

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'with un-sanitized parameters' do
      it 'sanitizes the input, stripping all tags and attributes that are not allowlisted' do
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
        it 'returns pagination meta data', :aggregate_failures do
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
          it 'passes the page request to the search service object' do
            expect(Search::Service).to receive(:new).with(query_term, '2')

            get '/v0/search', params: { query: query_term, page: 2 }
          end
        end

        context 'with no page present' do
          it 'passes page=nil to the search service object' do
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
