# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HealthQuest::V0::Apidocs', type: :request do
  describe 'GET /health_quest/v0/apidocs' do
    let(:openapi_version) { %w[openapi 3.0.0] }

    it 'has a success status' do
      get '/health_quest/v0/apidocs'

      expect(response).to have_http_status(:ok)
    end

    it 'has a correct openapi version' do
      get '/health_quest/v0/apidocs'

      expect(JSON.parse(response.body).first).to eq(openapi_version)
    end
  end
end
