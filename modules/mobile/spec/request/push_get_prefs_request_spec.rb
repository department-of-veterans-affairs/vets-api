# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'push get prefs', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  describe 'GET /mobile/v0/push/prefs/{endpointSid}' do
    context 'with a valid endpointSid' do
      it 'matches the get_prefs schema' do
        VCR.use_cassette('vetext/get_preferences_success') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('get_prefs')
        end
      end
    end

    context 'with a invalid endpointSid' do
      it 'returns bad request and errors' do
        VCR.use_cassette('vetext/get_preferences_bad_request') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: iam_headers
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error' do
      it 'returns bad gateway and errors' do
        VCR.use_cassette('vetext/get_preferences_internal_server_error') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: iam_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
