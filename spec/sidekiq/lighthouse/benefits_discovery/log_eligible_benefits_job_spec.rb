# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/service'

RSpec.describe Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob, type: :job do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }
  let(:service_instance) { instance_double(BenefitsDiscovery::Service) }
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
      allow(BenefitsDiscovery::Service).to receive(:new).and_return(service_instance)
    end

    context 'when all upstream services work' do
      before do
        allow(service_instance).to receive(:get_eligible_benefits).with(user.uuid).and_return(eligible_benefits)
      end

      it 'processes benefits discovery successfully' do
        expect(StatsD).to receive(:measure).with(described_class.name, be_a(Float))
        expect(StatsD).to receive(:increment).with(
          'Benefits Discovery Service results: [["not_recommended", []], ' \
          '["recommended", ["Health", "Life Insurance (VALife)"]], ["undetermined", []]]'
        )
        described_class.new.perform(user.uuid)
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
        expected_logged_error = 'Benefits Discovery Service results: [["not_recommended", ' \
                                '["Health", "Life Insurance (VALife)"]], ["recommended", ' \
                                '["Childcare", "Education"]], ["undetermined", ["Job Assistance", "Wealth"]]]'
        allow(service_instance).to receive(:get_eligible_benefits).with(user.uuid).and_return(benefits)
        expect(StatsD).to receive(:increment).with(expected_logged_error)
        described_class.new.perform(user.uuid)

        allow(service_instance).to receive(:get_eligible_benefits).with(user.uuid).and_return(reordered_benefits)
        expect(StatsD).to receive(:increment).with(expected_logged_error)
        described_class.new.perform(user.uuid)
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
        expect { described_class.new.perform(user.uuid) }.to raise_error(StandardError, 'Failed to prepare params')
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
        expect { described_class.new.perform(user.uuid) }.to raise_error(StandardError, 'API call failed')
      end
    end
  end
end
