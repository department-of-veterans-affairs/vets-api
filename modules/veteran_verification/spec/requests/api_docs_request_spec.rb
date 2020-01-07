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

  describe '#get /docs/v0/veteran_verification' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/veteran_verification/docs/v0/veteran_verification'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end

    it 'uses yaml that exists' do
      disability_yaml = VeteranVerification::Docs::V0::ApiController.new.send(:disability_rating_yaml)
      status_yaml = VeteranVerification::Docs::V0::ApiController.new.send(:status_yaml)
      service_history_yaml = VeteranVerification::Docs::V0::ApiController.new.send(:service_history_yaml)

      expect(disability_yaml['paths']['/disability_rating'].keys.size).to be > 0
      expect(disability_yaml['components']['schemas'].keys.size).to be > 0

      expect(status_yaml['paths']['/status'].keys.size).to be > 0
      expect(status_yaml['components']['schemas'].keys.size).to be > 0

      expect(service_history_yaml['paths']['/service_history'].keys.size).to be > 0
      expect(service_history_yaml['components']['schemas'].keys.size).to be > 0
    end
  end
end
