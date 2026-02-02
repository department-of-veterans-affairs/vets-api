# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack, type: :request do
  describe 'basic response format', type: :request do
    it 'returns valid HTTP responses' do
      get '/v0/status'

      expect(response.status).to be_between(100, 599)

      response.headers.each_key do |key|
        expect(key).to be_a(String)
      end

      expect(response.body).to be_a(String)
    end
  end

  describe 'middleware stack', type: :request do
    it 'processes requests without Rack 3.x compatibility errors' do
      get '/v0/status'
      expect(response.status).to be < 500

      post '/v0/status', params: { test: 'data' }
      expect(response.status).to be < 500
    end
  end
end
