# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'discovery', type: :request do
  include JsonSchemaMatchers
  describe 'GET /mobile' do
    context 'when the mobile_api flipper feature is enabled' do
      let(:expected_body) do
        {
          'data' => {
            'attributes' => {
              'message' => 'Welcome to the mobile API'
            }
          }
        }
      end

      let(:header) do
        { 'X-Key-Inflection' => 'camel' }
      end

      let(:auth_map) do
        {
          dev: 'https://sqa.fed.eauth.va.gov/oauthe/sps/oauth/oauth20/',
          staging: 'https://int.fed.eauth.va.gov/oauthe/sps/oauth/oauth20/',
          prod: 'https://fed.eauth.va.gov/oauthe/sps/oauth/oauth20/'
        }
      end

      let(:api_root_map) do
        {
          dev: 'https://staging-api.va.gov/mobile',
          staging: 'https://staging-api.va.gov/mobile',
          prod: 'https://api.va.gov/mobile'
        }
      end

      it 'returns the welcome message' do
        get '/mobile'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(expected_body)
      end

      it 'returns API 1.0 response with dev oauth url' do
        params = { environment: 'dev', buildNumber: '22', os: 'android' }
        post '/mobile', params: params, headers: header
        expect(response.body).to match_json_schema('discovery')
        expect(response.parsed_body.dig('data', 'attributes', 'authBaseUrl')).to eq(auth_map[:dev])
        expect(response.parsed_body.dig('data', 'attributes', 'apiRootUrl')).to eq(api_root_map[:dev])
        expect(response.parsed_body.dig('data', 'id')).to eq('1.0')
        expect(response).to have_http_status(:ok)
      end

      it 'returns API 1.0 response with staging oauth url' do
        params = { environment: 'staging', buildNumber: '27', os: 'ios' }
        post '/mobile', params: params, headers: header
        expect(response.body).to match_json_schema('discovery')
        expect(response.parsed_body.dig('data', 'attributes', 'authBaseUrl')).to eq(auth_map[:staging])
        expect(response.parsed_body.dig('data', 'attributes', 'apiRootUrl')).to eq(api_root_map[:staging])
        expect(response.parsed_body.dig('data', 'id')).to eq('1.0')
        expect(response).to have_http_status(:ok)
      end

      it 'returns API 1.0 response with prod oauth url' do
        params = { environment: 'prod', buildNumber: '55', os: 'android' }
        post '/mobile', params: params, headers: header
        expect(response.body).to match_json_schema('discovery')
        expect(response.parsed_body.dig('data', 'attributes', 'authBaseUrl')).to eq(auth_map[:prod])
        expect(response.parsed_body.dig('data', 'attributes', 'apiRootUrl')).to eq(api_root_map[:prod])
        expect(response.parsed_body.dig('data', 'id')).to eq('1.0')
        expect(response).to have_http_status(:ok)
      end

      it 'returns deprecated app version response' do
        params = { environment: 'prod', buildNumber: '10', os: 'ios' }
        post '/mobile', params: params, headers: header
        expect(response.body).to match_json_schema('discovery')
        expect(response.parsed_body.dig('data', 'attributes', 'authBaseUrl')).to eq('')
        expect(response.parsed_body.dig('data', 'attributes', 'apiRootUrl')).to eq('')
        expect(response.parsed_body.dig('data', 'attributes', 'appAccess')).to be(false)
        expect(response.parsed_body.dig('data', 'attributes', 'displayMessage')).to eq('Please update the app.')
        expect(response.parsed_body.dig('data', 'id')).to eq('deprecated')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the mobile_api flipper feature is disabled' do
      before { Flipper.disable('mobile_api') }

      it 'returns a 404' do
        get '/mobile'

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
