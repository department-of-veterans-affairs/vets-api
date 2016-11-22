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
    let(:session) { build :loa1_session }
    let(:user) { build :loa1_user, uuid: session.uuid, session: session }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(session.token) }

    before do
      Session.create(session)
      User.create(user)
    end

    it 'returns a JSON user profile' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :show
      assert_response :success

      json = JSON.parse(response.body)

      expect(json['data']['attributes']['profile']['email']).to eq(user.email)
    end
  end
end
