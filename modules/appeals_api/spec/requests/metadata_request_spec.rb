# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/health_checker'

RSpec.describe 'Appeals Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns decision reviews metadata JSON' do
      get '/services/appeals/decision_reviews/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end

    it 'returns appeals status metadata JSON' do
      get '/services/appeals/appeals_status/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  context 'healthchecks' do
    let(:health_check_stub) do
      health_checker = instance_double(AppealsApi::HealthChecker)
      allow(AppealsApi::HealthChecker).to receive(:new).and_return(health_checker)
      health_checker
    end

    context 'v0' do
      it 'returns correct response and status when healthy' do
        allow(health_check_stub).to receive(:services_are_healthy?).and_return(true)
        allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(true)

        get '/services/appeals/v0/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(true)
        expect(parsed_response['data']['attributes']['caseflow']['healthy']).to eq(true)
      end

      it 'returns correct status when caseflow is not healthy' do
        allow(health_check_stub).to receive(:services_are_healthy?).and_return(false)
        allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(false)

        get '/services/appeals/v0/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(false)
        expect(parsed_response['data']['attributes']['caseflow']['healthy']).to eq(false)
      end
    end

    context 'v1' do
      it 'returns correct response and status when healthy' do
        allow(health_check_stub).to receive(:services_are_healthy?).and_return(true)
        allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(true)

        get '/services/appeals/v1/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(true)
        expect(parsed_response['data']['attributes']['caseflow']['healthy']).to eq(true)
      end

      it 'returns correct status when caseflow is not healthy' do
        allow(health_check_stub).to receive(:services_are_healthy?).and_return(false)
        allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(false)

        get '/services/appeals/v1/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(false)
        expect(parsed_response['data']['attributes']['caseflow']['healthy']).to eq(false)
      end
    end
  end
end
