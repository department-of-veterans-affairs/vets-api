# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'Mobile Disability Rating API endpoint', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in
    Settings.vet_verification.mock_bgs = false
  end

  context 'with valid bgs responses' do
    it 'returns all the current user disability ratings and overall service connected combined degree' do
      with_okta_configured do
        VCR.use_cassette('bgs/rating_web_service/rating_data') do
          get '/mobile/v0/disability_rating', params: nil, headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_json_schema('disability_rating_response')
        end
      end
    end
  end

  context 'with error bgs response' do
    it 'returns all the current user disability ratings and overall service connected combined degree' do
      with_okta_configured do
        VCR.use_cassette('bgs/rating_web_service/rating_data_not_found') do
          get '/mobile/v0/disability_rating', params: nil, headers: iam_headers
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end
end
