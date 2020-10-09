# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'address', type: :request do
  include JsonSchemaMatchers

  describe 'PUT /mobile/v0/user/addresses' do
    before { iam_sign_in(user) }

    let(:user) { FactoryBot.build(:iam_user) }
    let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
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
end
