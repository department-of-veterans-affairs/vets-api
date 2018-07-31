# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VBA Document Uploads Documentation Endpoint', type: :request do
  describe '#get /docs/v0/appeals' do
    it 'should return Open API Spec v3 JSON' do
      get '/services/appeals/docs/v0/appeals'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#get /docs/v0/claims' do
    it 'should return Open API Spec v3 JSON' do
      get '/services/appeals/docs/v0/claims'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
