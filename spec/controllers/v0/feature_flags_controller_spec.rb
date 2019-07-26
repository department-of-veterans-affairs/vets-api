# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::FeatureFlagsController, type: :controller do
  describe 'GET #show' do
    it 'returns http success' do
      get :index, params: {features: "another_toggle,flipper_demo"}
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["flipper_demo"]).to be_falsey

    end
  end
end
