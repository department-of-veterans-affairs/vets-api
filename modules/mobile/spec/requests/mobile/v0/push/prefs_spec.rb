# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Push::Prefs', type: :request do
  include JsonSchemaMatchers
  let!(:user) { sis_user }

  describe 'GET /mobile/v0/push/prefs/{endpointSid}' do
    context 'with a valid endpointSid' do
      it 'matches the get_prefs schema' do
        VCR.use_cassette('vetext/get_preferences_success') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('get_prefs')
        end
      end
    end

    context 'with a invalid endpointSid' do
      it 'returns bad request and errors' do
        VCR.use_cassette('vetext/get_preferences_bad_request') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error' do
      it 'returns bad gateway and errors' do
        VCR.use_cassette('vetext/get_preferences_internal_server_error') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
