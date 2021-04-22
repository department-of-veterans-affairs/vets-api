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

  describe 'GET #index' do
    it 'returns all features' do
      get :index
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).not_to be_nil
    end

    it 'returns true for enabled flag' do
      get :index
      expect(response).to have_http_status(:ok)
      json_data = JSON.parse(response.body)

      expect(json_data['data']['features'].first['value']).not_to be_nil
      expect(json_data['data']['features']).to include({ 'name' => @feature_name_camel, 'value' => true })
      expect(json_data['data']['features']).to include({ 'name' => @feature_name, 'value' => true })
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

    it 'tests that both casing forms are returned properly' do
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
  end
end
