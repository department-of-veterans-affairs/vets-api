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
      expect(response).to have_http_status(200)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
    end

    it 'keeps flags in format recieved' do
      get :index, params: { features: @feature_name.camelize }
      expect(response).to have_http_status(200)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].first['name']).to eq(@feature_name.camelize)
    end

    it 'returns false for nonexistant flags' do
      @feature_name =  'thisIsNotARealFlag'
      get :index, params: { features: @feature_name }

      expect(response).to have_http_status(200)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
      expect(json_data['data']['features'].first['value']).to be_falsey
    end
  end
end
