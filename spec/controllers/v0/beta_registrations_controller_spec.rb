# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BetaRegistrationsController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show, params: { feature: 'profile-beta' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in' do
    let(:user) { build(:user) }

    before(:each) do
      sign_in_as(user)
    end

    it 'returns 404 if not enrolled in beta' do
      get :show, params: { feature: 'profile-beta' }
      expect(response).to have_http_status(:not_found)
    end

    it 'enrolls user in beta successfully' do
      get :create, params: { feature: 'profile-beta' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['user']).to eq(user.email)
    end

    it 'returns OK status if enrolled in beta' do
      BetaRegistration.find_or_create_by(user_uuid: user.uuid, feature: 'profile-beta')
      get :show, params: { feature: 'profile-beta' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['user']).to eq(user.email)
    end

    it 'successfully unenrolls user from beta' do
      get :destroy, params: { feature: 'profile-beta' }
      expect(response).to have_http_status(:no_content)
    end
  end
end
