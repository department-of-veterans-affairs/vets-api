# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Intent to file', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/intent_to_file' do
    context 'with a valid evss response' do
      it 'should match the intent to files schema' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file') do
          get '/v0/intent_to_file', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_files')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file_403') do
          get '/v0/intent_to_file', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('intent_to_file_errors', strict: false)
        end
      end
    end

    context 'with a 400 invalid intent type' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/intent_to_file_intent_type_invalid') do
          get '/v0/intent_to_file', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('intent_to_file_errors')
        end
      end
    end
  end

  describe 'GET /v0/intent_to_file/compensation/active' do
    context 'with a valid evss response' do
      it 'should match the intent to file schema' do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          get '/v0/intent_to_file/compensation/active', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_file')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/intent_to_file/active_compensation_403') do
          get '/v0/intent_to_file/compensation/active', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('intent_to_file_errors', strict: false)
        end
      end
    end

    context 'with a 502 partner service invalid' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/active_compensation_partner_service_invalid') do
          get '/v0/intent_to_file/compensation/active', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('intent_to_file_errors')
        end
      end
    end
  end

  describe 'POST /v0/intent_to_file/compensation' do
    context 'with a valid evss response' do
      it 'should match the intent to file schema' do
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post '/v0/intent_to_file/compensation', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_file')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_403') do
          post '/v0/intent_to_file/compensation', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('intent_to_file_errors', strict: false)
        end
      end
    end

    context 'with a 502 partner service error' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_partner_service_error') do
          post '/v0/intent_to_file/compensation', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('intent_to_file_errors')
        end
      end
    end

    context 'with a 400 intent type invalid' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/intent_to_file/create_compensation_type_error') do
          post '/v0/intent_to_file/compensation', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('intent_to_file_errors')
        end
      end
    end
  end

  describe 'Invalid `type` in path' do
    context 'to GET /v0/intent_to_file/{type}/active' do
      it 'should raise a bad request error' do
        get '/v0/intent_to_file/invalid/active', nil, auth_header
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'to POST /v0/intent_to_file/{type}' do
      it 'should raise a bad request error' do
        post '/v0/intent_to_file/invalid', nil, auth_header
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
