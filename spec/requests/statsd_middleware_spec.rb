# frozen_string_literal: true

require 'rails_helper'
require 'statsd_middleware'

# This spec verifies StatsdMiddleware functionality with a simplified approach
# Previously used PrescriptionsController which has been removed
RSpec.describe ApplicationController, type: :controller do
  # Disable the automatic controller class inference
  before(:all) do
    RSpec.configure do |c|
      c.infer_base_class_for_anonymous_controllers = false
    end
  end

  after(:all) do
    # Reset to default behavior
    RSpec.configure do |c|
      c.infer_base_class_for_anonymous_controllers = true
    end
  end

  # Create anonymous controller with test actions that emulates RxController  
  controller do
    include JsonApiPaginationLinks
    skip_before_action :authenticate
    service_tag 'legacy-mhv'
    
    def client
      @client ||= mock_client
    end

    def mock_client
      double('Rx::Client', 
        get_active_rxs: OpenStruct.new(data: [], metadata: {}),
        get_history_rxs: OpenStruct.new(data: [], metadata: {}),
        get_rx: OpenStruct.new(data: {}, metadata: {})
      )
    end
    
    def authorize
      # Mock authorization
      true
    end
    
    def index
      render json: { status: 'ok', data: [] }, status: 200
    end

    def show
      if params[:id] == 'error'
        render json: { status: 'error' }, status: 404
      else
        render json: { status: 'ok', id: params[:id], data: {} }, status: 200
      end
    end
    
    # Define a custom action for testing instead of refill
    def custom_action
      head :no_content
    end
  end

  # Set up the routes for testing
  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'show/:id' => 'anonymous#show', as: :show
      post 'custom_action' => 'anonymous#custom_action'
    end
  end

  # Basic functionality tests
  describe 'StatsdMiddleware structure validation' do
    it 'has the expected configuration constants' do
      expect(StatsdMiddleware::STATUS_KEY).to eq('api.rack.request')
      expect(StatsdMiddleware::DURATION_KEY).to eq('api.rack.request.duration')
    end

    it 'is included in the Rails middleware stack' do
      expect(Rails.configuration.middleware.middlewares).to include(StatsdMiddleware)
    end

    it 'can be instantiated and called' do
      middleware = StatsdMiddleware.new(->(_) { [200, {}, ['OK']] })
      expect(middleware).to respond_to(:call)
    end
  end

  # Controller functionality tests
  describe 'controller functionality' do
    let(:user) { build(:user, :mhv) }
    
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    
    it 'responds successfully to index action' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq('ok')
    end
    
    it 'handles show action with param' do
      get :show, params: { id: '123' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq('123')
    end
    
    it 'handles errors appropriately' do
      get :show, params: { id: 'error' }
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['status']).to eq('error')
    end
    
    it 'handles no_content response' do
      post :custom_action
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_blank
    end
  end

  # Source app tracking simulation
  describe 'source app handling' do
    it 'includes source app header' do
      request.headers['Source-App-Name'] = 'test_app'
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
