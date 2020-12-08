# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'address', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'PUT /mobile/v0/user/addresses' do
    before { iam_sign_in(user) }

    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }

    context 'with a valid address' do
      before do
        VCR.use_cassette('vet360/contact_information/put_address_success') do
          put '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('profile_update_response')
      end

      it 'includes a transaction id' do
        id = JSON.parse(response.body).dig('data', 'attributes', 'transactionId')
        expect(id).to eq('63e7792c-887e-4d57-b6ed-801edcae2c2d')
      end
    end

    context 'with missing address params' do
      before do
        address.address_line1 = ''

        put('/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers))
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the error schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'has a helpful error message' do
        message = response.parsed_body['errors'].first
        expect(message).to eq(
          {
            'title' => "Address line1 can't be blank",
            'detail' => "address-line1 - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/address-line1'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'POST /mobile/v0/user/addresses/validate' do
    context 'with an invalid address' do
      let(:invalid_address) { build(:vet360_validation_address) }

      before do
        post '/mobile/v0/user/addresses/validate',
             params: invalid_address.to_json, headers: iam_headers(json_body_headers)
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'returns the error details' do
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => "Address line1 can't be blank",
              'detail' => "address-line1 - can't be blank",
              'code' => '100', 'source' =>
              { 'pointer' => 'data/attributes/address-line1' },
              'status' => '422'
            },
            {
              'title' => "City can't be blank",
              'detail' => "city - can't be blank",
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/city'
              },
              'status' => '422'
            },
            {
              'title' => "State code can't be blank",
              'detail' => "state-code - can't be blank",
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/state-code'
              },
              'status' => '422'
            },
            {
              'title' =>
                "Zip code can't be blank",
              'detail' => "zip-code - can't be blank",
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/zip-code'
              },
              'status' => '422'
            }
          ]
        )
      end
    end

    context 'with a found address' do
      let(:multiple_match_address) { build(:vet360_address, :multiple_matches) }

      before do
        VCR.use_cassette(
          'vet360/address_validation/candidate_multiple_matches',
          VCR::MATCH_EVERYTHING
        ) do
          post '/mobile/v0/user/addresses/validate',
               params: multiple_match_address.to_json, headers: iam_headers(json_body_headers)
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('suggested_addresses')
      end

      it 'includes suggested correct addresses for a given address' do
        expect(response.parsed_body['data'][0]['attributes']).to eq(
          {
            'addressLine1' => '37 N 1st St',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPou' => nil,
            'addressType' => 'DOMESTIC',
            'city' => 'Brooklyn',
            'countryCodeIso3' => 'USA',
            'internationalPostalCode' => nil,
            'province' => nil,
            'stateCode' => 'NY',
            'zipCode' => '11249',
            'zipCodeSuffix' => '3939'
          }
        )
      end

      it 'includes the confidence score for the address' do
        expect(response.parsed_body['data'][0]['meta']).to eq(
          {
            'confidenceScore' => 100.0,
            'addressType' => 'Domestic',
            'deliveryPointValidation' => 'UNDELIVERABLE',
            'validationKey' => -646_932_106
          }
        )
      end
    end
  end
end
