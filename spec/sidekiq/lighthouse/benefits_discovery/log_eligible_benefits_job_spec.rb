# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/service'
require 'lighthouse/benefits_discovery/params'

RSpec.describe Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob, type: :job do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }
  let(:user_uuid) { user.uuid }
  let(:prepared_params) do
    {
      dateOfBirth: '1980-01-01',
      dischargeStatus: ['HONORABLE'],
      branchOfService: ['ARMY'],
      disabilityRating: 60,
      serviceDates: [{ beginDate: '2001-01-01', endDate: '2005-01-01' }]
    }
  end
  let(:eligible_benefits) do
    {
      'status' => 'success',
      'data' => {
        'benefits' => [
          { 'id' => 'benefit1', 'name' => 'Education Benefits' },
          { 'id' => 'benefit2', 'name' => 'Health Care' }
        ]
      }
    }
  end

  describe '#perform' do
    before do
      params_instance = instance_double(BenefitsDiscovery::Params)
      service_instance = instance_double(BenefitsDiscovery::Service)

      allow(BenefitsDiscovery::Params).to receive(:new).with(user_uuid).and_return(params_instance)
      allow(params_instance).to receive(:prepared_params).and_return(prepared_params)

      allow(BenefitsDiscovery::Service).to receive(:new).and_return(service_instance)
      allow(service_instance).to receive(:get_eligible_benefits).with(prepared_params).and_return(eligible_benefits)
    end

    it 'processes benefits discovery successfully' do
      expect(Rails.logger).to receive(:info).with(/Processed BenefitsDiscovery params for user: #{user_uuid}, execution_time: \d+\.\d+ seconds/)
      Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob.new.perform(user_uuid)
    end

    context 'when params preparation fails' do
      before do
        allow_any_instance_of(BenefitsDiscovery::Params).to receive(:prepared_params).and_raise(StandardError, 'Failed to prepare params')
      end

      it 'logs error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with("Failed to process BenefitsDiscovery for user: #{user_uuid}, error: Failed to prepare params")
        expect { Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob.new.perform(user_uuid) }.to raise_error(StandardError, 'Failed to prepare params')
      end
    end

    context 'when service call fails' do
      before do
        allow_any_instance_of(BenefitsDiscovery::Service).to receive(:get_eligible_benefits).and_raise(StandardError, 'API call failed')
      end

      it 'logs error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with("Failed to process BenefitsDiscovery for user: #{user_uuid}, error: API call failed")
        expect { Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob.new.perform(user_uuid) }.to raise_error(StandardError, 'API call failed')
      end
    end
  end
end
