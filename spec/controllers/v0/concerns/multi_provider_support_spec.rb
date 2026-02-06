# frozen_string_literal: true

require 'rails_helper'

# Test controller for V0::Concerns::MultiProviderSupport specs
class V0MultiProviderSupportTestController
  include V0::Concerns::MultiProviderSupport

  STATSD_METRIC_PREFIX = 'api.benefits_claims'
  STATSD_TAGS = ['controller:benefits_claims'].freeze

  attr_accessor :current_user

  def initialize(user)
    @current_user = user
  end
end

RSpec.describe V0::Concerns::MultiProviderSupport do
  let(:user) { double('User') }
  let(:controller) { V0MultiProviderSupportTestController.new(user) }
  let(:provider_class) { double('ProviderClass', name: 'TestProvider') }
  let(:provider_instance) { double('Provider') }

  before do
    allow(provider_class).to receive(:new).with(user).and_return(provider_instance)
    allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
      .with(user)
      .and_return([provider_class])
  end

  describe '#format_error_entry' do
    it 'returns error with string keys for provider and error' do
      result = controller.send(:format_error_entry, 'TestProvider', 'Service unavailable')

      expect(result).to eq({
                             'provider' => 'TestProvider',
                             'error' => 'Service unavailable'
                           })
    end
  end

  describe '#format_get_claims_response' do
    it 'returns hash with data and meta keys' do
      claims_data = [{ 'id' => '1' }, { 'id' => '2' }]
      errors = [{ 'provider' => 'TestProvider', 'error' => 'Failed' }]

      result = controller.send(:format_get_claims_response, claims_data, errors)

      expect(result).to eq({
                             'data' => claims_data,
                             'meta' => { 'provider_errors' => errors }
                           })
    end

    it 'compacts meta when no errors' do
      claims_data = [{ 'id' => '1' }]
      errors = []

      result = controller.send(:format_get_claims_response, claims_data, errors)

      expect(result).to eq({
                             'data' => claims_data,
                             'meta' => {}
                           })
    end
  end

  describe '#statsd_metric_name' do
    it 'uses controller STATSD_METRIC_PREFIX' do
      result = controller.send(:statsd_metric_name, 'provider_error')

      expect(result).to eq('api.benefits_claims.provider_error')
    end
  end

  describe '#statsd_tags_for_provider' do
    it 'includes controller STATSD_TAGS and provider tag' do
      result = controller.send(:statsd_tags_for_provider, 'TestProvider')

      expect(result).to eq(['controller:benefits_claims', 'provider:TestProvider'])
    end
  end

  describe 'integration with base module' do
    describe '#get_claims_from_providers' do
      it 'returns web-formatted response' do
        allow(provider_instance).to receive(:get_claims).and_return({
                                                                      'data' => [{ 'id' => '1' }]
                                                                    })

        result = controller.send(:get_claims_from_providers)

        expect(result).to have_key('data')
        expect(result).to have_key('meta')
        expect(result['data']).to eq([{ 'id' => '1' }])
      end

      it 'includes provider errors in meta' do
        allow(provider_instance).to receive(:get_claims).and_raise(StandardError.new('Failed'))
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)

        result = controller.send(:get_claims_from_providers)

        expect(result['data']).to eq([])
        expect(result['meta']['provider_errors']).to be_present
        expect(result['meta']['provider_errors'].first['provider']).to eq('TestProvider')
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

      it 'requires type parameter when multiple providers exist' do
        provider_class2 = double('ProviderClass2', name: 'TestProvider2')
        provider_instance2 = double('Provider2')
        allow(provider_class2).to receive(:new).with(user).and_return(provider_instance2)
        allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
          .with(user)
          .and_return([provider_class, provider_class2])
        allow(controller).to receive(:supported_provider_types).and_return(%w[lighthouse test])

        expect do
          controller.send(:get_claim_from_providers, claim_id)
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end

      it 'routes to correct provider when type parameter specified' do
        lighthouse_class = BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider
        lighthouse_instance = double('LighthouseProvider')
        allow(lighthouse_class).to receive(:new).with(user).and_return(lighthouse_instance)
        allow(lighthouse_instance).to receive(:get_claim).with(claim_id).and_return({ 'data' => { 'id' => claim_id } })

        result = controller.send(:get_claim_from_providers, claim_id, 'lighthouse')

        expect(result).to eq({ 'data' => { 'id' => claim_id } })
      end
    end
  end
end
