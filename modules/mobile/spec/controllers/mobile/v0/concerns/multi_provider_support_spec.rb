# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

# Test controller for Mobile::V0::Concerns::MultiProviderSupport specs
class MobileMultiProviderSupportTestController
  include Mobile::V0::Concerns::MultiProviderSupport

  attr_accessor :current_user

  def initialize(user)
    @current_user = user
  end
end

RSpec.describe Mobile::V0::Concerns::MultiProviderSupport do
  let(:user) { double('User') }
  let(:controller) { MobileMultiProviderSupportTestController.new(user) }
  let(:provider_class) { double('ProviderClass', name: 'TestProvider') }
  let(:provider_instance) { double('Provider') }

  before do
    allow(provider_class).to receive(:new).with(user).and_return(provider_instance)
    allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
      .with(user)
      .and_return([provider_class])
  end

  describe '#format_error_entry' do
    it 'returns error with symbol keys for service and error_details' do
      result = controller.send(:format_error_entry, 'TestProvider', 'Service unavailable')

      expect(result).to eq({
                             service: 'TestProvider',
                             error_details: 'Service unavailable'
                           })
    end
  end

  describe '#format_get_claims_response' do
    it 'returns tuple of claims_data and errors' do
      claims_data = [{ 'id' => '1' }, { 'id' => '2' }]
      errors = [{ service: 'TestProvider', error_details: 'Failed' }]

      result = controller.send(:format_get_claims_response, claims_data, errors)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result[0]).to eq(claims_data)
      expect(result[1]).to eq(errors)
    end

    it 'returns empty arrays when no data or errors' do
      result = controller.send(:format_get_claims_response, [], [])

      expect(result).to eq([[], []])
    end
  end

  describe '#statsd_metric_name' do
    it 'uses hardcoded mobile prefix' do
      result = controller.send(:statsd_metric_name, 'provider_error')

      expect(result).to eq('mobile.claims_and_appeals.provider_error')
    end

    it 'works with get_claim action' do
      result = controller.send(:statsd_metric_name, 'get_claim.provider_error')

      expect(result).to eq('mobile.claims_and_appeals.get_claim.provider_error')
    end
  end

  describe '#statsd_tags_for_provider' do
    it 'returns only provider tag' do
      result = controller.send(:statsd_tags_for_provider, 'TestProvider')

      expect(result).to eq(['provider:TestProvider'])
    end
  end

  describe 'integration with base module' do
    describe '#get_claims_from_providers' do
      it 'returns mobile-formatted tuple' do
        allow(provider_instance).to receive(:get_claims).and_return({
                                                                      'data' => [{ 'id' => '1' }]
                                                                    })

        result = controller.send(:get_claims_from_providers)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0]).to eq([{ 'id' => '1' }])
        expect(result[1]).to eq([])
      end

      it 'includes provider errors in second element of tuple' do
        allow(provider_instance).to receive(:get_claims).and_raise(StandardError.new('Failed'))
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)

        result = controller.send(:get_claims_from_providers)

        claims_list, errors = result
        expect(claims_list).to eq([])
        expect(errors).to be_present
        expect(errors.first[:service]).to eq('TestProvider')
        expect(errors.first[:error_details]).to eq('Provider temporarily unavailable')
      end

      it 'aggregates claims from multiple providers' do
        provider_class2 = double('ProviderClass2', name: 'TestProvider2')
        provider_instance2 = double('Provider2')
        allow(provider_class2).to receive(:new).with(user).and_return(provider_instance2)
        allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
          .with(user)
          .and_return([provider_class, provider_class2])
        allow(provider_instance).to receive(:get_claims).and_return({
                                                                      'data' => [{ 'id' => '1' }]
                                                                    })
        allow(provider_instance2).to receive(:get_claims).and_return({
                                                                       'data' => [{ 'id' => '2' }]
                                                                     })

        claims_list, errors = controller.send(:get_claims_from_providers)

        expect(claims_list.length).to eq(2)
        expect(claims_list).to eq([{ 'id' => '1' }, { 'id' => '2' }])
        expect(errors).to eq([])
      end
    end

    describe '#get_claim_from_providers' do
      let(:claim_id) { '123' }

      it 'returns claim when response has data' do
        allow(provider_instance).to receive(:get_claim).with(claim_id).and_return({
                                                                                    'data' => { 'id' => claim_id }
                                                                                  })

        result = controller.send(:get_claim_from_providers, claim_id)

        expect(result).to eq({ 'data' => { 'id' => claim_id } })
      end

      it 'skips provider when response has nil data' do
        provider_class2 = double('ProviderClass2', name: 'TestProvider2')
        provider_instance2 = double('Provider2')
        allow(provider_class2).to receive(:new).with(user).and_return(provider_instance2)
        allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
          .with(user)
          .and_return([provider_class, provider_class2])

        # First provider returns nil data (should be skipped)
        allow(provider_instance).to receive(:get_claim).with(claim_id).and_return({
                                                                                    'data' => nil
                                                                                  })
        # Second provider has the claim
        allow(provider_instance2).to receive(:get_claim).with(claim_id).and_return({
                                                                                     'data' => { 'id' => claim_id }
                                                                                   })
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)

        result = controller.send(:get_claim_from_providers, claim_id)

        expect(result).to eq({ 'data' => { 'id' => claim_id } })
      end

      it 'raises RecordNotFound when no provider has valid data' do
        allow(provider_instance).to receive(:get_claim).with(claim_id).and_return({
                                                                                    'data' => nil
                                                                                  })
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)

        expect do
          controller.send(:get_claim_from_providers, claim_id)
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end

      it 'tracks metrics with mobile prefix' do
        allow(provider_instance).to receive(:get_claim)
          .with(claim_id)
          .and_raise(StandardError.new('Failed'))
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)

        expect do
          controller.send(:get_claim_from_providers, claim_id)
        end.to raise_error(Common::Exceptions::RecordNotFound)

        expect(StatsD).to have_received(:increment).with(
          'mobile.claims_and_appeals.get_claim.provider_error',
          tags: ['provider:TestProvider']
        )
      end
    end
  end
end
