# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'email', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/profile/email' do
    it 'returns a status of 200' do
      VCR.use_cassette('evss/pciu/email') do
        get '/v0/profile/email', nil, auth_header

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('email_address_response')
      end
    end
  end
end
