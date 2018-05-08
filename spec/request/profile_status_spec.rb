# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'profile_status', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    # vet360_id appears in the API request URI so we need it to match the cassette
    allow_any_instance_of(Mvi).to receive(:response_from_redis_or_service).and_return(
      MVI::Responses::FindProfileResponse.new(
        status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
        profile: build(:mvi_profile, vet360_id: '1')
      )
    )
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/profile/status/:transaction_id' do
    let(:address) { build(:vet360_address, source_id: '1', transaction_status: 'RECEIVED') }

    context 'when the requested transaction exists' do
      it 'it responds with a serialized transaction', :aggregate_failures do
        transaction = create(
          :address_transaction,
          user_uuid: user.uuid,
          transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2'
        )

        VCR.use_cassette('vet360/contact_information/address_transaction_status') do
          get(
            "/v0/profile/status/#{transaction.transaction_id}",
            nil,
            auth_header
          )
          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body['data']['type']).to eq('async_transaction_vet360_address_transactions')
          # @TODO The ...data.attributes.type has the original, non-snake-cased version of the class
        end
      end
    end
  end
end
