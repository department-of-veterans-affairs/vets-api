# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Confirmation Documentation Endpoints', type: :request do
  describe '#get /veteran_confirmation/v0/health' do
    it 'returns health status in JSON' do
      get '/services/veteran_confirmation/v0/health'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      status = body['UP']
      expect(status).to eq(true)
    end
  end
end
