# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::ExampleController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :welcome
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns rate limited message' do
      get :limited
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when logged in' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:test_user) { FactoryBot.build(:user) }

    before(:each) do
      Session.create(uuid: test_user.uuid, token: token)
      User.create(test_user)
    end

    it 'returns a welcome string with user email in it' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :welcome
      assert_response :success
      expect(JSON.parse(response.body)['message']).to eq("You are logged in as #{test_user.email}")
    end
  end
end
