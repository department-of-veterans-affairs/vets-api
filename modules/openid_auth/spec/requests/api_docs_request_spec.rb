# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Validation Documentation Endpoint', type: :request do
  describe '#get /docs/v2/validation' do
    it 'returns Open API Spec v3 JSON' do
      get '/internal/auth/docs/v2/validation'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
