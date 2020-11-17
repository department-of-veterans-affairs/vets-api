# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/health_checker'
require 'mvi/service'

describe ClaimsApi::HealthChecker do
  describe 'something' do
    it 'returns correct response and status when healthy' do
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:mpi_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      expect(ClaimsApi::HealthChecker.new.services_are_healthy?).to eq(true)
    end

    it 'returns correct status when evss is not healthy' do
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:mpi_is_healthy?).and_return(true)
      allow(Breakers::Outage).to receive(:find_latest)
        .and_return(OpenStruct.new(start_time: Time.zone.now))
      expect(ClaimsApi::HealthChecker.new.services_are_healthy?).to eq(false)
    end

    it 'returns correct status when mpi is not healthy' do
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      allow(MVI::Service).to receive(:service_is_up?).and_return(false)
      expect(ClaimsApi::HealthChecker.new.services_are_healthy?).to eq(false)
    end

    it 'returns correct status when vbms is not healthy' do
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:mpi_is_healthy?).and_return(true)
      # VBMS does not have upper level access yet, just return true
      # allow(Faraday).to receive(:get).and_return(OpenStruct.new(status: 503))
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(false)
      expect(ClaimsApi::HealthChecker.new.services_are_healthy?).to eq(false)
    end

    it 'returns correct status when bgs is not healthy' do
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:mpi_is_healthy?).and_return(true)
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
      # BGS does not have upper level access yet, just return true
      # allow(Faraday).to receive(:get).and_return(OpenStruct.new(status: 503))
      allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(false)
      expect(ClaimsApi::HealthChecker.new.services_are_healthy?).to eq(false)
    end
  end
end
