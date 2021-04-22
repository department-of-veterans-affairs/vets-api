# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::FeatureTogglesController, type: :controller do
  before(:all) do
    @feature_name = 'facility_locator_show_community_cares'
    @feature_name_camel = @feature_name.camelize(:lower)
    @cached_enabled_val = Flipper.enabled?(@feature_name)
    Flipper.enable(@feature_name)
  end

  after(:all) do
    @cached_enabled_val ? Flipper.enable(@feature_name) : Flipper.disable(@feature_name)
  end

  describe 'GET #index without params' do
    it 'returns all features' do
      get :index
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).not_to be_nil
    end

    it 'allows strings as actors' do
      @feature_name =  'ssoe'
      @feature_name_camel = @feature_name.camelize(:lower)
      @cookie_id = 'abc_123'
      actor = Flipper::Actor.new(@cookie_id)
      Flipper.disable(@feature_name)
      Flipper.enable_actor(@feature_name, actor)

      get :index, params: { cookie_id: @cookie_id }

      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features']).to include({ 'name' => @feature_name_camel, 'value' => true })
      expect(json_data['data']['features']).to include({ 'name' => @feature_name, 'value' => true })
    end

    it 'tests that both casing forms (snake and camel) are returned properly' do
      get :index, params: { cookie_id: @cookie_id }

      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).not_to be_nil
      expect(json_data['data']['features']).to include({ 'name' => @feature_name_camel, 'value' => true })
      expect(json_data['data']['features']).to include({ 'name' => @feature_name, 'value' => true })
    end
  end

  describe 'GET #index with params' do
    it 'returns true for enabled flags' do
      get :index, params: { features: @feature_name }
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
      expect(json_data['data']['features'].count).to eq(1)
    end

    it 'keeps flags in format recieved' do
      get :index, params: { features: @feature_name.camelize }
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].first['name']).to eq(@feature_name.camelize)
      expect(json_data['data']['features'].count).to eq(1)
    end

    it 'returns false for nonexistant flags' do
      @feature_name =  'thisIsNotARealFlag'
      get :index, params: { features: @feature_name }

      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
      expect(json_data['data']['features'].first['value']).to be_falsey
    end

    it 'allows strings as actors' do
      @feature_name =  'ssoe'
      @cookie_id = 'abc_123'
      actor = Flipper::Actor.new(@cookie_id)
      Flipper.disable(@feature_name)
      Flipper.enable_actor(@feature_name, actor)

      get :index, params: { features: @feature_name, cookie_id: @cookie_id }

      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['name']).to eq(@feature_name)
      expect(json_data['data']['features'].first['value']).to be true
      expect(json_data['data']['features'].count).to eq(1)
    end
  end
end
