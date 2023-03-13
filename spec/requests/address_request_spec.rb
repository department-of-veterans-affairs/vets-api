# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'address' do
  include SchemaMatchers

  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:camel_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:headers_with_camel) { headers.merge(camel_header) }
  let(:current_user) { create(:evss_user) }

  before do
    sign_in_as(current_user)
  end

  describe '#reference_data_service.enabled=false' do
    before do
      allow(Settings.evss.reference_data_service).to receive(:enabled).and_return(false)
    end

    describe 'GET /v0/address' do
      context 'with a military address' do
        it 'matches the address schema' do
          VCR.use_cassette('evss/pciu_address/address') do
            get '/v0/address'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('address_response')
          end
        end

        it 'matches the address schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/address') do
            get '/v0/address', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('address_response')
          end
        end
      end

      context 'with a domestic address' do
        # domestic and international addresses are manually edited as EVSS CI only includes one military response
        it 'matches the address schema' do
          VCR.use_cassette('evss/pciu_address/address_domestic') do
            get '/v0/address'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('address_response')
          end
        end

        it 'matches the address schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/address_domestic') do
            get '/v0/address', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('address_response')
          end
        end
      end

      context 'with an international address' do
        # domestic and international addresses are manually edited as EVSS CI only includes one military response
        it 'matches the address schema' do
          VCR.use_cassette('evss/pciu_address/address_international') do
            get '/v0/address'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('address_response')
          end
        end

        it 'matches the address schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/address_international') do
            get '/v0/address', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('address_response')
          end
        end
      end

      context 'with a 500 response' do
        it 'matches the errors schema' do
          VCR.use_cassette('evss/pciu_address/address_500') do
            get '/v0/address'
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('errors')
          end
        end

        it 'matches the errors schema with camel-inflection' do
          VCR.use_cassette('evss/pciu_address/address_500') do
            get '/v0/address', headers: camel_header
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end
    end

    describe 'PUT /v0/address' do
      context 'with a 200 response' do
        let(:domestic_address) { build(:pciu_domestic_address) }

        it 'matches the address schema' do
          VCR.use_cassette('evss/pciu_address/address_update') do
            put '/v0/address', params: domestic_address.to_json, headers: headers
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('address_response')
          end
        end

        it 'matches the address schema when camel-infelcted' do
          VCR.use_cassette('evss/pciu_address/address_update') do
            put '/v0/address', params: domestic_address.to_json, headers: headers_with_camel
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('address_response')
          end
        end
      end

      context 'with a 422 response' do
        let(:domestic_address) { build(:pciu_domestic_address, address_one: nil, country_name: nil) }

        it 'matches the errors schema' do
          VCR.use_cassette('evss/pciu_address/address_500') do
            put '/v0/address', params: domestic_address.to_json, headers: headers
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response).to match_response_schema('errors')
          end
        end

        it 'matches the errors schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/address_500') do
            put '/v0/address', params: domestic_address.to_json, headers: headers_with_camel
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end

      context 'with an address field that is too long' do
        let(:long_address) { '140 Rock Creek Church Rd NW upon the Potomac' }
        let(:domestic_address) { build(:pciu_domestic_address, address_one: long_address) }

        it 'matches the errors schema' do
          VCR.use_cassette('evss/pciu_address/address_update_invalid_format') do
            put '/v0/address', params: domestic_address.to_json, headers: headers
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response).to match_response_schema('errors')
          end
        end

        it 'matches the errors schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/address_update_invalid_format') do
            put '/v0/address', params: domestic_address.to_json, headers: headers_with_camel
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end

      context 'with a 500 response' do
        it 'matches the errors schema' do
          VCR.use_cassette('evss/pciu_address/address_500') do
            get '/v0/address'
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('errors')
          end
        end

        it 'matches the errors schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/address_500') do
            get '/v0/address', headers: camel_header
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end
    end

    describe 'GET /v0/address/states' do
      context 'with a 200 response' do
        it 'matches the states schema' do
          VCR.use_cassette('evss/pciu_address/states') do
            get '/v0/address/states'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('states')
          end
        end

        it 'matches the states schema with camel-inflection' do
          VCR.use_cassette('evss/pciu_address/states') do
            get '/v0/address/states', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('states')
          end
        end
      end
    end

    describe 'GET /v0/address/countries' do
      context 'with a 200 response' do
        it 'matches the countries schema' do
          VCR.use_cassette('evss/pciu_address/countries') do
            get '/v0/address/countries'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('countries')
          end
        end

        it 'matches the countries schema when camel-inflected' do
          VCR.use_cassette('evss/pciu_address/countries') do
            get '/v0/address/countries', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('countries')
          end
        end
      end
    end
  end

  describe '#reference_data_service.enabled=true' do
    before do
      allow(Settings.evss.reference_data_service).to receive(:enabled).and_return(true)
    end

    describe 'GET /v0/address/countries' do
      context 'with a 200 response' do
        it 'matches the countries schema' do
          VCR.use_cassette('evss/reference_data/countries') do
            get '/v0/address/countries'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('countries')
          end
        end

        it 'matches the countries schema when camel-inflected' do
          VCR.use_cassette('evss/reference_data/countries') do
            get '/v0/address/countries', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('countries')
          end
        end
      end
    end

    describe 'GET /v0/address/states' do
      context 'with a 200 response' do
        it 'matches the states schema' do
          VCR.use_cassette('evss/reference_data/states') do
            get '/v0/address/states'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('states')
          end
        end

        it 'matches the states schema with camel-inflection' do
          VCR.use_cassette('evss/reference_data/states') do
            get '/v0/address/states', headers: camel_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('states')
          end
        end
      end
    end
  end
end
