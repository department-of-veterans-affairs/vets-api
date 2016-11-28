# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::ExampleController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :welcome
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in' do
    let(:loa1_session) { build :loa1_session }
    let(:loa1_user) { build :loa1_user, uuid: loa1_session.uuid }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(loa1_session.token) }

    before(:each) do
      Session.create(loa1_session)
      User.create(loa1_user)
    end

    it 'returns a welcome string with user email in it' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :welcome
      assert_response :success
      expect(JSON.parse(response.body)['message']).to eq("You are logged in as #{loa1_user.email}")
    end
  end
end
