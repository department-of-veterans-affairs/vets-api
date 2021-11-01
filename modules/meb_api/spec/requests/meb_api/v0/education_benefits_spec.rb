# frozen_string_literal: true

require 'rails_helper'

Rspec.describe MebApi::V0::EducationBenefitsController, type: :request do
  describe 'GET /meb_api/v0/claimant_info' do
    it 'successfully returns JSON' do
      get '/meb_api/v0/claimant_info'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body).to_yaml
    end
  end

  describe 'GET /meb_api/v0/service_history' do
    it 'successfully returns JSON' do
      get '/meb_api/v0/service_history'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body).to_yaml
    end
  end

  describe 'GET /meb_api/v0/eligibility' do
    it 'successfully returns JSON' do
      get '/meb_api/v0/eligibility'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body).to_yaml
    end
  end

  describe 'GET /meb_api/v0/claim_status' do
    it 'successfully returns JSON' do
      get '/meb_api/v0/claim_status'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body).to_yaml
    end
  end

  describe 'POST /meb_api/v0/claim_status' do
    it 'successfully returns JSON' do
      post '/meb_api/v0/submit_claim'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body).to_yaml
    end
  end
end
