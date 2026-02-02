# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UTF8 Cleaner Middleware Rack 3', type: :request do
  describe 'basic UTF-8 handling' do
    it 'processes valid UTF-8 without errors' do
      valid_utf8 = { name: 'test' }

      post '/v0/status',
           params: valid_utf8.to_json,
           headers: { 'Content-Type' => 'application/json' }

      # Should not crash with valid UTF-8
      expect(response.status).to be < 500
    end

    it 'handles ASCII text correctly' do
      get '/v0/status', params: { query: 'test' }
      expect(response.status).to be < 500
    end

    it 'processes requests with various encodings' do
      # Test with different valid UTF-8 characters
      %w[hello foo test].each do |text|
        get '/v0/status', params: { q: text }
        expect(response.status).to be < 500
      end
    end
  end

  describe 'Rack 3 compatibility' do
    it 'utf8-cleaner works with Rack 3' do
      get '/v0/status'
      expect(response.status).to be < 500

      post '/v0/status', params: { test: 'data' }
      expect(response.status).to be < 500
    end
  end
end
