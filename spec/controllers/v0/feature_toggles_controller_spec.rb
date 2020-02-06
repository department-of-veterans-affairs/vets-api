# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::FeatureTogglesController, type: :controller do
  before(:all) do
    @feature_name = 'facility_locator_show_community_cares'
    @cached_enabled_val = Flipper.enabled?(@feature_name)
    Flipper.enable(@feature_name)
  end

  after(:all) do
    @cached_enabled_val ? Flipper.enable(@feature_name) : Flipper.disable(@feature_name)
  end

  describe 'GET #show' do
    it 'returns true for enabled flags' do
      get :index, params: { features: @feature_name }
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
    end

    it 'keeps flags in format recieved' do
      get :index, params: { features: @feature_name.camelize }
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].first['name']).to eq(@feature_name.camelize)
    end

    it 'returns false for nonexistant flags' do
      @feature_name =  'thisIsNotARealFlag'
      get :index, params: { features: @feature_name }

      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
      expect(json_data['data']['features'].first['value']).to be_falsey
    end

    it 'returns features if present ' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('{"data":{"type":"feature_toggles","features":[]}}')
    end

    it 'allows strings as actors' do
      @feature_name =  'ssoe'
      @cookie_id = 'abc_123'
      actor = V0::FeatureTogglesController::FlipperActor.new(@cookie_id)
      Flipper.disable(@feature_name)
      Flipper.enable_actor(@feature_name, actor)

      get :index, params: { features: @feature_name, cookie_id: @cookie_id }

      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
      expect(json_data['data']['features'].first['value']).to be true
    end
  end
end
