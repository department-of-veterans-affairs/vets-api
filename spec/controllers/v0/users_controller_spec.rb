# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::UsersController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:test_user) { FactoryGirl.build(:user) }

    before(:each) do
      Session.create(uuid: test_user.uuid, token: token)
      User.create(test_user)
    end

    it 'returns a JSON user profile' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :show
      assert_response :success

      json = JSON.parse(response.body)

      expect(json['uuid']).to eq(test_user.uuid)
      expect(json['email']).to eq(test_user.email)
    end
  end
end
