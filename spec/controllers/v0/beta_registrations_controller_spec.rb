# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BetaRegistrationsController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show, feature: 'profile-beta'
      expect(response).to have_http_status(:unauthorized)
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

    it 'returns 404 if not enrolled in beta' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :show, feature: 'profile-beta'
      expect(response).to have_http_status(404)
    end

    it 'enrolls user in beta successfully' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :create, feature: 'profile-beta'
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['user']).to eq(test_user.email)
    end

    it 'returns OK status if enrolled in beta' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      BetaRegistration.find_or_create_by(user_uuid: test_user.uuid, feature: 'profile-beta')
      get :show, feature: 'profile-beta'
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['user']).to eq(test_user.email)
    end

    it 'successfully unenrolls user from beta' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :destroy, feature: 'profile-beta'
      expect(response).to have_http_status(204)
    end
  end
end
