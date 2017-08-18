# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Requesting ID Card Attributes', type: :request do

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe '#show /v0/id_card_attributes' do
    it 'should return a signed redirect URL' do
      get '/v0/id_card_attributes', nil, auth_header
      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to be
      # TODO add specs to verify signing with self-signed test cert
    end
  end
end
