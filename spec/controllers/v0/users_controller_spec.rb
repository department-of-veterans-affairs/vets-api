# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::UsersController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in as an LOA1 user' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:loa1_user) { build(:user, :loa1) }

    before(:each) do
      Session.create(uuid: loa1_user.uuid, token: token)
      User.create(loa1_user)
      FactoryBot.create(:in_progress_form, user_uuid: loa1_user.uuid, form_id: 'edu-1990')
    end

    it 'returns a JSON user profile' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :show
      assert_response :success

      json = JSON.parse(response.body)
      expect(json['data']['attributes']['profile']['email']).to eq(loa1_user.email)
    end
  end
end
