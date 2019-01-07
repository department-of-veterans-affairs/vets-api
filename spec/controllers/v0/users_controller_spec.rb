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
    let(:user) { build(:user, :loa1) }

    it 'returns a JSON user profile' do
      sign_in_as(user)
      FactoryBot.create(:in_progress_form, user_uuid: user.uuid, form_id: 'edu-1990')
      get :show
      assert_response :success

      json = JSON.parse(response.body)
      expect(json['data']['attributes']['profile']['email']).to eq(user.email)
    end
  end
end
