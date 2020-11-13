# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'transactions', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v0/user/transactions/:transaction_id' do
    before { iam_sign_in(user) }

    let(:user) { FactoryBot.build(:iam_user) }
    let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
    let(:transaction) do
      create(
        :address_transaction,
        user_uuid: user.uuid,
        transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6'
      )
    end

    context 'with an existing transaction' do
      let(:transaction_response) do
        response.parsed_body.dig('data', 'attributes')
      end

      before do
        VCR.use_cassette('vet360/contact_information/address_transaction_status') do
          get("/mobile/v0/user/transactions/#{transaction.transaction_id}", headers: iam_headers(json_body_headers))
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the transaction schema' do
        expect(response.body).to match_json_schema('profile_update_response')
      end

      it 'includes the correct transaction id' do
        expect(transaction_response['transactionId']).to eq(transaction.transaction_id)
      end
    end

    context 'when the transaction is not found' do
      let(:not_found_transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }

      before do
        VCR.use_cassette('vet360/contact_information/address_transaction_status_error') do
          get("/mobile/v0/user/transactions/#{not_found_transaction_id}", headers: iam_headers(json_body_headers))
        end
      end

      it 'returns a 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'matches the errors schema' do
        expect(response.body).to match_json_schema('errors')
      end
    end
  end
end
