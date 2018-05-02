# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'profile_status', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/profile/status/:transaction_id' do

    let(:address) { build(:vet360_address, source_id: '1', transaction_status: 'RECEIVED' ) }

    context 'when the requested transaction exists' do
      it 'it should return a 200 ', :aggregate_failures do

        transaction = create(:address_transaction, {user_uuid: user.uuid, transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2'})
        
        # @TODO This is a temporary shim while I figure out how to alter the vet360_id to match the existing cassette
        VCR.use_cassette('vet360/contact_information/address_transaction_status2') do
          get(
            "/v0/profile/status/#{transaction.transaction_id}",
            nil,
            auth_header
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
