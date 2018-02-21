# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'address', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/address' do
    context 'with a military address' do
      it 'should match the address schema' do
        VCR.use_cassette('evss/pciu_address/address') do
          get '/v0/address', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('address_response')
        end
      end
    end

    context 'with a domestic address' do
      it 'should match the address schema' do
        # domestic and international addresses are manually edited as EVSS CI only includes one military response
        VCR.use_cassette('evss/pciu_address/address_domestic') do
          get '/v0/address', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('address_response')
        end
      end
    end

    context 'with an international address' do
      it 'should match the address schema' do
        # domestic and international addresses are manually edited as EVSS CI only includes one military response
        VCR.use_cassette('evss/pciu_address/address_international') do
          get '/v0/address', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('address_response')
        end
      end
    end

    context 'with a 500 response' do
      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu_address/address_500') do
          get '/v0/address', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end

  describe 'PUT /v0/address' do
    context 'with a 200 response' do
      let(:domestic_address) { build(:pciu_domestic_address) }

      it 'should match the address schema' do
        VCR.use_cassette('evss/pciu_address/address_update') do
          put '/v0/address', domestic_address.to_json, auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('address_response')
        end
      end
    end

    context 'with a 422 response' do
      let(:domestic_address) { build(:pciu_domestic_address, address_one: nil, country_name: nil) }

      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu_address/address_500') do
          put '/v0/address', domestic_address.to_json, auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an address field that is too long' do
      let(:long_address) { '140 Rock Creek Church Rd NW upon the Potomac' }
      let(:domestic_address) { build(:pciu_domestic_address, address_one: long_address) }

      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu_address/address_update_invalid_format') do
          put '/v0/address', domestic_address.to_json, auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 500 response' do
      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu_address/address_500') do
          get '/v0/address', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end

  describe 'GET /v0/address/rds/states' do
    context 'with a 200 response' do
      it 'should match the states schema' do
        VCR.use_cassette('evss/reference_data/states') do
          get '/v0/address/rds/states', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('states')
        end
      end
    end
  end

  describe 'GET /v0/address/rds/countries' do
    context 'with a 200 response' do
      it 'should match the states schema' do
        VCR.use_cassette('evss/reference_data/countries') do
          get '/v0/address/rds/countries', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('countries')
        end
      end
    end
  end

  describe 'GET /v0/address/states' do
    context 'with a 200 response' do
      it 'should match the states schema' do
        VCR.use_cassette('evss/pciu_address/states') do
          get '/v0/address/states', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('states')
        end
      end
    end
  end

  describe 'GET /v0/address/countries' do
    context 'with a 200 response' do
      it 'should match the countries schema' do
        VCR.use_cassette('evss/pciu_address/countries') do
          get '/v0/address/countries', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('countries')
        end
      end
    end

    context 'with a 401 malformed token response', vcr: { cassette_name: 'evss/reference_data/401_malformed' } do
      before do
        allow_any_instance_of(EVSS::ReferenceData::Service)
          .to receive(:headers_for_user)
          .and_return(Authorization: 'Bearer abcd12345asd')
      end
      it 'should return 502' do
        get '/v0/address/rds/countries', nil, auth_header
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
