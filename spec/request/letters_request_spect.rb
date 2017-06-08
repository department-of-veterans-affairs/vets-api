# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'letters', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    Settings.evss.mock_letters = false
  end

  describe 'GET /v0/letters' do
    context 'with a valid evss response' do
      it 'should match the letters schema' do
        VCR.use_cassette('evss/letters/letters') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letters')
        end
      end
    end
    # TODO(AJD): not found and server error response handling
  end
end
