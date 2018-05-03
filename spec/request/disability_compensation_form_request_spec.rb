# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability compensation form', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'Get /v0/disability_compensation_form/rated_disabilities' do
    context 'with a valid evss response' do
      it 'should match the rated disabilities schema' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('rated_disabilities')
        end
      end
    end

    context 'with a 500 response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('rated_disabilities_errors', strict: false)
        end
      end
    end

    context 'with a 403 unauthorized response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('rated_disabilities_errors', strict: false)
        end
      end
    end

    context 'with a generic 400 response' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('rated_disabilities_errors', strict: false)
        end
      end
    end
  end

  describe 'Get /v0/disability_compensation_form/submit' do
    context 'with a valid evss response' do
      let(:valid_form_content) { File.read 'spec/support/disability_compensation_submit_data.json' }

      it 'should match the rated disabilities schema' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('submit_disability_form')
        end
      end
    end

    context 'with a 500 response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500') do
          post '/v0/disability_compensation_form/submit', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('disability_compensation_form_submit_errors', strict: false)
        end
      end
    end

    context 'with a 403 unauthorized response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/disability_compensation_form/submit_403') do
          post '/v0/disability_compensation_form/submit', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('disability_compensation_form_submit_errors', strict: false)
        end
      end
    end

    context 'with a generic 400 response' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          post '/v0/disability_compensation_form/submit', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('disability_compensation_form_submit_errors', strict: false)
        end
      end
    end
  end
end
