# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Forms Documentation Endpoint', type: :request do
  describe '#get /docs/v1/api' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/va_forms/docs/v0/api'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
