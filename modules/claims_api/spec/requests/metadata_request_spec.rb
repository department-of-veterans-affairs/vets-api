# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/health_checker'

RSpec.describe 'Claims Status Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/claims/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  context 'healthchecks' do
    context 'v0' do
      it 'returns correct response and status when healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:services_are_healthy?).and_return(true)
        get '/services/claims/v0/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(true)
      end

      it 'returns correct status when evss is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(false)
        get '/services/claims/v0/healthcheck'
        expect(response.status).to eq(503)
      end

      it 'returns correct status when mvi is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(false)
        get '/services/claims/v0/healthcheck'
        expect(response.status).to eq(503)
      end

      it 'returns correct status when vbms is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(false)
        get '/services/claims/v0/healthcheck'
        expect(response.status).to eq(503)
      end

      it 'returns correct status when bgs is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(false)
        get '/services/claims/v0/healthcheck'
        expect(response.status).to eq(503)
      end
    end

    context 'v1' do
      it 'returns correct response and status when healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:services_are_healthy?).and_return(true)
        get '/services/claims/v1/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(true)
      end

      it 'returns correct status when evss is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(false)
        get '/services/claims/v1/healthcheck'
        expect(response.status).to eq(503)
      end

      it 'returns correct status when mvi is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(false)
        get '/services/claims/v1/healthcheck'
        expect(response.status).to eq(503)
      end

      it 'returns correct status when vbms is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(false)
        get '/services/claims/v1/healthcheck'
        expect(response.status).to eq(503)
      end

      it 'returns correct status when bgs is not healthy' do
        allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
        allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(false)
        get '/services/claims/v1/healthcheck'
        expect(response.status).to eq(503)
      end
    end
  end
end
