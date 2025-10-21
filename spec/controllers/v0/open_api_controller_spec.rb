# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::OpenAPIController, type: :controller do
  describe 'GET #index' do
    it 'returns a successful response' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end

    it 'returns valid OpenAPI specification structure' do
      get :index

      json = JSON.parse(response.body)

      expect(json).to have_key('openapi')
      expect(json).to have_key('info')
      expect(json).to have_key('paths')
      expect(json['openapi']).to eq('3.0.3')
    end

    it 'includes Form 21-4192 endpoint in paths' do
      get :index

      json = JSON.parse(response.body)

      expect(json['paths']).to have_key('/v0/form214192')
      expect(json['paths']['/v0/form214192']).to have_key('post')
    end

    it 'does not require authentication' do
      # Make request without signing in
      get :index

      expect(response).to have_http_status(:ok)
    end
  end
end
