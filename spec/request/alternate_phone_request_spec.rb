# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'alternate phone', type: :request do
  include SchemaMatchers

  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  before(:each) { sign_in }

  describe 'GET /v0/profile/alternate_phone' do
    context 'with a 200 response' do
      it 'should match the alternate phone schema' do
        VCR.use_cassette('evss/pciu/alternate_phone') do
          get '/v0/profile/alternate_phone'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('phone_number_response')
        end
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu/alternate_phone_status_400') do
          get '/v0/profile/alternate_phone'

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('evss/pciu/alternate_phone_status_403') do
          get '/v0/profile/alternate_phone'

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a 500 response' do
      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu/alternate_phone_status_500') do
          get '/v0/profile/alternate_phone'

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end

  describe 'POST /v0/profile/alternate_phone' do
    let(:phone) { build(:phone_number, :nil_effective_date) }

    context 'with a 200 response' do
      it 'should match the phone schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_alternate_phone') do
          post('/v0/profile/alternate_phone', params: phone.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('phone_number_response')
        end
      end
    end

    context 'with a missing phone number' do
      it 'should match the errors schema', :aggregate_failures do
        phone = build :phone_number, :nil_effective_date, number: ''

        post('/v0/profile/alternate_phone', params: phone.to_json, headers: headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "number - can't be blank", 'number - Only numbers are permitted.'
      end
    end

    context 'with a number that contains non-numeric characters' do
      it 'should match the errors schema', :aggregate_failures do
        phone = build :phone_number, :nil_effective_date, number: '123-456-7890'

        post('/v0/profile/alternate_phone', params: phone.to_json, headers: headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'number - Only numbers are permitted.'
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_alternate_phone_status_400') do
          post('/v0/profile/alternate_phone', params: phone.to_json, headers: headers)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('evss/pciu/post_alternate_phone_status_403') do
          post('/v0/profile/alternate_phone', params: phone.to_json, headers: headers)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a 500 response' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_alternate_phone_status_500') do
          post('/v0/profile/alternate_phone', params: phone.to_json, headers: headers)

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end
end
