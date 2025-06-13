# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/service'
require 'lighthouse/benefits_discovery/params'

RSpec.describe Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob, type: :job do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }
  let(:params_instance) { instance_double(BenefitsDiscovery::Params) }
  let(:service_instance) { instance_double(BenefitsDiscovery::Service) }
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
      'undetermined' => [],
      'recommended' => [
        {
          'benefit_name' => 'Life Insurance (VALife)',
          'benefit_url' => 'https://www.va.gov/life-insurance/'
        },
        {
          'benefit_name' => 'Health',
          'benefit_url' => 'https://www.va.gov/health-care/'
        }
      ],
      'not_recommended' => []
    }
  end

  describe '#perform' do
    before do
      allow(BenefitsDiscovery::Params).to receive(:new).with(user.uuid).and_return(params_instance)
      allow(BenefitsDiscovery::Service).to receive(:new).and_return(service_instance)
    end

    context 'when all upstream services work' do
      before do
        allow(params_instance).to receive(:prepared_params).and_return(prepared_params)
        allow(service_instance).to receive(:get_eligible_benefits).with(prepared_params).and_return(eligible_benefits)
      end

      it 'processes benefits discovery successfully' do
        expect(StatsD).to receive(:measure).with(described_class.name, be_a(Float))
        expect(StatsD).to receive(:increment).with(
          {
            not_recommended: [],
            recommended: [
              { benefit_name: 'Health', benefit_url: 'https://www.va.gov/health-care/' },
              { benefit_name: 'Life Insurance (VALife)', benefit_url: 'https://www.va.gov/life-insurance/' }
            ],
            undetermined: []
          }.to_json
        )
        described_class.new.perform(user.uuid)
      end
    end

    context 'when params preparation fails' do
      before do
        allow(params_instance).to receive(:prepared_params).and_raise(StandardError, 'Failed to prepare params')
      end

      it 'logs error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(
          "Failed to process BenefitsDiscovery for user: #{user.uuid}, error: Failed to prepare params"
        )
        expect { described_class.new.perform(user.uuid) }.to raise_error(StandardError, 'Failed to prepare params')
      end
    end

    context 'when service call fails' do
      before do
        allow(params_instance).to receive(:prepared_params).and_return(prepared_params)
        allow(service_instance).to receive(:get_eligible_benefits).and_raise(StandardError, 'API call failed')
      end

      it 'logs error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(
          "Failed to process BenefitsDiscovery for user: #{user.uuid}, error: API call failed"
        )
        expect { described_class.new.perform(user.uuid) }.to raise_error(StandardError, 'API call failed')
      end
    end
  end
end
