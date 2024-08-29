# frozen_string_literal: true

require_relative '../support/helpers/rails_helper'

RSpec.describe 'Mobile', type: :request do
  describe 'GET /mobile' do
    before { get '/mobile' }

    it 'returns a 200' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns a welcome message and list of mobile endpoints' do
      attributes = response.parsed_body.dig('data', 'attributes')
      expect(attributes['message']).to eq('Welcome to the mobile API.')
      expect(attributes['endpoints']).to include('mobile/v0/appeal/:id', 'mobile/v0/appointments')
    end
  end
end
