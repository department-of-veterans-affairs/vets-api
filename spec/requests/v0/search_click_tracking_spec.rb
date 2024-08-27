# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'
require 'uri'

Rspec.describe 'V0::SearchClickTracking', type: :request do
  include ErrorDetails

  describe 'POST /v0/search_click_tracking' do
    context 'on a successfull post request' do
      let(:query_params) do
        URI.encode_www_form(
          {
            position: 0,
            query: 'testQuery',
            url: 'https://www.testurl.com',
            user_agent: 'testUserAgent',
            module_code: 'I14Y'
          }
        )
      end

      it 'returns a response of 204 No Content', :aggregate_failures do
        VCR.use_cassette('search_click_tracking/success') do
          post "/v0/search_click_tracking/?#{query_params}"
          expect(response).to have_http_status(:no_content)
          expect(response.body).to eq ''
        end
      end
    end

    context 'with a missing parameter' do
      let(:query_params) do
        URI.encode_www_form(
          {
            position: 0,
            query: '',
            url: 'https://www.testurl.com',
            user_agent: 'testUserAgent',
            module_code: 'I14Y'
          }
        )
      end

      it 'returns a 400', :aggregate_failures do
        VCR.use_cassette('search_click_tracking/missing_parameter') do
          post "/v0/search_click_tracking/?#{query_params}"
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
