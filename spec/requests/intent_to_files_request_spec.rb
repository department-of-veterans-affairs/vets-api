# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe 'Intent to file' do
  include SchemaMatchers

  before do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
    sign_in
  end

  let(:camel_inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  describe 'GET /v0/intent_to_file' do
    context 'with a valid evss response' do
      it 'matches the intent to files schema' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file') do
          get '/v0/intent_to_file'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_files')
        end
      end

      it 'matches the intent to files schema when camel-inflected' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file') do
          get '/v0/intent_to_file', headers: camel_inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('intent_to_files')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file_403') do
          get '/v0/intent_to_file'
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end

      it 'returns a not authorized response with camel-inflection' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file_403') do
          get '/v0/intent_to_file', headers: camel_inflection_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_camelized_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 400 invalid intent type' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file_intent_type_invalid') do
          get '/v0/intent_to_file'
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors')
        end
      end

      it 'returns a bad gateway response when camel-inflected' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file_intent_type_invalid') do
          get '/v0/intent_to_file', headers: camel_inflection_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('evss_errors')
        end
      end
    end
  end

  describe 'GET /v0/intent_to_file/compensation/active' do
    context 'with a valid evss response' do
      it 'matches the intent to file schema' do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          get '/v0/intent_to_file/compensation/active'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_file')
        end
      end

      it 'matches the intent to file schema with camel-inflection' do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          get '/v0/intent_to_file/compensation/active', headers: camel_inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('intent_to_file')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/intent_to_file/active_compensation_403') do
          get '/v0/intent_to_file/compensation/active'
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end

      it 'returns a not authorized response when camel-inflected' do
        VCR.use_cassette('evss/intent_to_file/active_compensation_403') do
          get '/v0/intent_to_file/compensation/active', headers: camel_inflection_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_camelized_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 502 partner service invalid' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/active_compensation_partner_service_invalid') do
          get '/v0/intent_to_file/compensation/active'
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors')
        end
      end

      it 'returns a bad gateway response when camel-inlfected' do
        VCR.use_cassette('evss/intent_to_file/active_compensation_partner_service_invalid') do
          get '/v0/intent_to_file/compensation/active', headers: camel_inflection_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('evss_errors')
        end
      end
    end
  end

  describe 'POST /v0/intent_to_file/compensation' do
    context 'with a valid evss response' do
      it 'matches the intent to file schema' do
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post '/v0/intent_to_file/compensation'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_file')
        end
      end

      it 'matches the intent to file schema when camel-inflected' do
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post '/v0/intent_to_file/compensation', headers: camel_inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('intent_to_file')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_403') do
          post '/v0/intent_to_file/compensation'
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end

      it 'returns a not authorized response when camel-inflected' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_403') do
          post '/v0/intent_to_file/compensation', headers: camel_inflection_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_camelized_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 502 partner service error' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_partner_service_error') do
          post '/v0/intent_to_file/compensation'
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors')
        end
      end

      it 'returns a bad gateway response with camel-inflection' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_partner_service_error') do
          post '/v0/intent_to_file/compensation', headers: camel_inflection_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('evss_errors')
        end
      end
    end

    context 'with a 400 intent type invalid' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_type_error') do
          post '/v0/intent_to_file/compensation'
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors')
        end
      end

      it 'returns a bad gateway response with camel-inflection' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_type_error') do
          post '/v0/intent_to_file/compensation', headers: camel_inflection_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('evss_errors')
        end
      end
    end
  end

  describe 'Invalid `type` in path' do
    context 'to GET /v0/intent_to_file/{type}/active' do
      it 'raises a bad request error' do
        get '/v0/intent_to_file/invalid/active'
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'to POST /v0/intent_to_file/{type}' do
      it 'raises a bad request error' do
        post '/v0/intent_to_file/invalid'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
