# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Verification Documentation Endpoints', type: :request do
  describe '#get /docs/v0/service_history' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/veteran_verification/docs/v0/service_history'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#get /docs/v0/disability_rating' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/veteran_verification/docs/v0/disability_rating'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#get /docs/v0/status' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/veteran_verification/docs/v0/status'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#get /docs/v0/metadata' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/veteran_verification/docs/v0/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
