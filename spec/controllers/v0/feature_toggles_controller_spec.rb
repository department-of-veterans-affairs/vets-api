# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::FeatureTogglesController, type: :controller do
  describe 'GET #show' do
    it 'returns http success' do
      get :index, params: { features: 'flipper_demo,another_toggle' }

      expect(response).to have_http_status(200)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be_falsey
    end
  end
end
