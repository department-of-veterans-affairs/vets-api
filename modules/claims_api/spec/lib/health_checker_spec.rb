# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/health_checker'

describe ClaimsApi::HealthChecker do
  describe 'something' do
    it 'returns correct response and status when healthy' do
      allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      expect(ClaimsApi::HealthChecker.services_are_healthy?).to eq(true)
    end

    it 'returns correct status when evss is not healthy' do
      allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
      allow(EVSS::Service).to receive(:service_is_up?).and_return(false)
      expect(ClaimsApi::HealthChecker.services_are_healthy?).to eq(false)
    end

    it 'returns correct status when mvi is not healthy' do
      allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      allow(MVI::Service).to receive(:service_is_up?).and_return(false)
      expect(ClaimsApi::HealthChecker.services_are_healthy?).to eq(false)
    end

    it 'returns correct status when vbms is not healthy' do
      allow(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
      allow(Faraday).to receive(:get).and_return(OpenStruct.new(status: 503))
      expect(ClaimsApi::HealthChecker.services_are_healthy?).to eq(false)
    end

    it 'returns correct status when bgs is not healthy' do
      allow(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:mvi_is_healthy?).and_return(true)
      allow(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow(Faraday).to receive(:get).and_return(OpenStruct.new(status: 503))
      expect(ClaimsApi::HealthChecker.services_are_healthy?).to eq(false)
    end
  end
end
