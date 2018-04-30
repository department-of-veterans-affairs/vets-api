# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'telephone', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'POST /v0/profile/telephones' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'should match the telephone schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_telephone_success') do
          post(
            '/v0/profile/telephones',
            {
              area_code: '303',
              country_code: '1',
              international_indicator: false,
              phone_number: '5551234',
              phone_type: 'MOBILE'
            }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
