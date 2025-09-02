# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob, type: :job do
  let(:user) { create(:user, :loa3, :accountable, :legacy_icn) }
  let(:service_instance) { instance_double(BenefitsDiscovery::Service) }
  let(:params_instance) { instance_double(BenefitsDiscovery::Params) }
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
  let(:prepared_params) { { doesnt: 'matter' } }
  let(:prepared_service_history) { { stilldoesnt: 'matter' } }

  describe '#perform' do
    before do
      allow(BenefitsDiscovery::Service).to receive(:new).with(
        api_key: Settings.lighthouse.benefits_discovery.x_api_key,
        app_id: Settings.lighthouse.benefits_discovery.x_app_id
      ).and_return(service_instance)
      allow(BenefitsDiscovery::Params).to receive(:new).and_return(params_instance)
      allow(params_instance).to \
        receive(:build_from_service_history).with(prepared_service_history).and_return(prepared_params)
    end

    context 'when all upstream services work' do
      before do
        allow(service_instance).to receive(:get_eligible_benefits).with(prepared_params).and_return(eligible_benefits)
      end

      it 'processes benefits discovery successfully' do
        expect(StatsD).to receive(:measure).with(described_class.name, be_a(Float))
        expected_tags = 'eligible_benefits:not_recommended//recommended/Health:Life Insurance (VALife)/undetermined//'
        expect(StatsD).to receive(:increment).with('benefits_discovery_logging', { tags: [expected_tags] })
        described_class.new.perform(user.uuid, prepared_service_history)
      end

      it 'always logs items in the same order' do
        benefits = {
          'undetermined' => [
            {
              'benefit_name' => 'Job Assistance',
              'benefit_url' => 'https://www.va.gov/job-assistance/'
            },
            {
              'benefit_name' => 'Wealth',
              'benefit_url' => 'https://www.va.gov/wealth/'
            }
          ],
          'not_recommended' => [
            {
              'benefit_name' => 'Life Insurance (VALife)',
              'benefit_url' => 'https://www.va.gov/life-insurance/'
            },
            {
              'benefit_name' => 'Health',
              'benefit_url' => 'https://www.va.gov/health-care/'
            }
          ],
          'recommended' => [
            {
              'benefit_name' => 'Education',
              'benefit_url' => 'https://www.va.gov/education/'
            },
            {
              'benefit_name' => 'Childcare',
              'benefit_url' => 'https://www.va.gov/childcare/'
            }
          ]
        }
        reordered_benefits = {
          'recommended' => [
            {
              'benefit_name' => 'Childcare',
              'benefit_url' => 'https://www.va.gov/childcare/'
            },
            {
              'benefit_name' => 'Education',
              'benefit_url' => 'https://www.va.gov/education/'
            }
          ],
          'not_recommended' => [
            {
              'benefit_name' => 'Health',
              'benefit_url' => 'https://www.va.gov/health-care/'
            },
            {
              'benefit_name' => 'Life Insurance (VALife)',
              'benefit_url' => 'https://www.va.gov/life-insurance/'
            }
          ],
          'undetermined' => [
            {
              'benefit_name' => 'Wealth',
              'benefit_url' => 'https://www.va.gov/wealth/'
            },
            {
              'benefit_name' => 'Job Assistance',
              'benefit_url' => 'https://www.va.gov/job-assistance/'
            }
          ]
        }
        expected_tags = 'eligible_benefits:not_recommended/Health:Life Insurance (VALife)' \
                        '/recommended/Childcare:Education/undetermined/Job Assistance:Wealth/'
        allow(service_instance).to receive(:get_eligible_benefits).and_return(benefits)
        expect(StatsD).to receive(:increment).with('benefits_discovery_logging', { tags: [expected_tags] })
        described_class.new.perform(user.uuid, prepared_service_history)

        allow(service_instance).to receive(:get_eligible_benefits).and_return(reordered_benefits)
        expect(StatsD).to receive(:increment).with('benefits_discovery_logging', { tags: [expected_tags] })
        described_class.new.perform(user.uuid, prepared_service_history)
      end
    end

    context 'when user cannot be found' do
      it 'raises error' do
        expect { described_class.new.perform('abc123', prepared_service_history) }.to \
          raise_error(Common::Exceptions::RecordNotFound, 'Record not found')
      end
    end

    context 'when params preparation fails' do
      before do
        allow(service_instance).to receive(:get_eligible_benefits).and_raise(StandardError, 'Failed to prepare params')
      end

      it 'logs error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(
          "Failed to process eligible benefits for user: #{user.uuid}, error: Failed to prepare params"
        )
        expect do
          described_class.new.perform(user.uuid,
                                      prepared_service_history)
        end.to raise_error(StandardError, 'Failed to prepare params')
      end
    end

    context 'when service call fails' do
      before do
        allow(service_instance).to receive(:get_eligible_benefits).and_raise(StandardError, 'API call failed')
      end

      it 'logs error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(
          "Failed to process eligible benefits for user: #{user.uuid}, error: API call failed"
        )
        expect do
          described_class.new.perform(user.uuid, prepared_service_history)
        end.to raise_error(StandardError, 'API call failed')
      end
    end
  end
end
