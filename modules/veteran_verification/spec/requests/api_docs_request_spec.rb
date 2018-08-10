# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Verification Documentation Endpoints', type: :request do
  describe '#get /docs/v0/service_history' do
    it 'should return Open API Spec v3 JSON' do
      get '/services/veteran_verification/docs/v0/service_history'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
