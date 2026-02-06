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
  let(:user) { double('User', icn: '1008596379V859838') }
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

      context 'with single provider' do
        context 'when single provider is Lighthouse' do
          before do
            lighthouse_class = BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider
            allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
              .with(user)
              .and_return([lighthouse_class])
          end

          it 'routes through proxy (applies mobile-specific transforms)' do
            proxy = double('LighthouseProxy')
            allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new).with(user).and_return(proxy)
            allow(proxy).to receive(:get_claim).with(claim_id).and_return({ 'data' => { 'id' => claim_id } })

            result = controller.send(:get_claim_from_providers, claim_id, nil)

            expect(result).to eq({ 'data' => { 'id' => claim_id } })
            expect(Mobile::V0::LighthouseClaims::Proxy).to have_received(:new).with(user)
            expect(proxy).to have_received(:get_claim).with(claim_id)
          end
        end

        context 'when single provider is non-Lighthouse' do
          before do
            allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
              .with(user)
              .and_return([provider_class])
          end

          it 'routes directly to provider (bypasses proxy)' do
            allow(provider_instance).to receive(:get_claim).with(claim_id).and_return({
                                                                                        'data' => { 'id' => claim_id }
                                                                                      })
            # Verify Proxy is NOT called
            allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new)

            result = controller.send(:get_claim_from_providers, claim_id, nil)

            expect(result).to eq({ 'data' => { 'id' => claim_id } })
            expect(provider_class).to have_received(:new).with(user)
            expect(provider_instance).to have_received(:get_claim).with(claim_id)
            expect(Mobile::V0::LighthouseClaims::Proxy).not_to have_received(:new)
          end
        end
      end

      context 'with multiple providers' do
        let(:provider_class2) { double('ProviderClass2', name: 'TestProvider2') }
        let(:provider_instance2) { double('Provider2') }

        before do
          allow(provider_class2).to receive(:new).with(user).and_return(provider_instance2)
          allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
            .with(user)
            .and_return([provider_class, provider_class2])
        end

        it 'defaults to lighthouse when type parameter is missing' do
          proxy = double('LighthouseProxy')
          allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new).with(user).and_return(proxy)
          allow(proxy).to receive(:get_claim).with(claim_id).and_return({ 'data' => { 'id' => claim_id } })

          result = controller.send(:get_claim_from_providers, claim_id)

          expect(result).to eq({ 'data' => { 'id' => claim_id } })
          expect(Mobile::V0::LighthouseClaims::Proxy).to have_received(:new).with(user)
          expect(proxy).to have_received(:get_claim).with(claim_id)
        end

        it 'routes lighthouse to proxy (applies mobile-specific transforms)' do
          proxy = double('LighthouseProxy')
          allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new).with(user).and_return(proxy)
          allow(proxy).to receive(:get_claim).with(claim_id).and_return({ 'data' => { 'id' => claim_id } })

          result = controller.send(:get_claim_from_providers, claim_id, 'lighthouse')

          expect(result).to eq({ 'data' => { 'id' => claim_id } })
          expect(Mobile::V0::LighthouseClaims::Proxy).to have_received(:new).with(user)
          expect(proxy).to have_received(:get_claim).with(claim_id)
        end

        it 'routes non-lighthouse providers directly to provider (bypasses proxy)' do
          champva_class = double('ChampvaProviderClass', name: 'ChampvaProvider')
          champva_instance = double('ChampvaProvider')
          allow(champva_class).to receive(:new).with(user).and_return(champva_instance)
          allow(champva_instance).to receive(:get_claim).with(claim_id)
            .and_return({ 'data' => { 'id' => claim_id } })

          # Stub provider_class_for_type to return non-Lighthouse provider
          allow(controller).to receive(:provider_class_for_type).with('champva').and_return(champva_class)

          # Verify Proxy is NOT called
          allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new)

          result = controller.send(:get_claim_from_providers, claim_id, 'champva')

          expect(result).to eq({ 'data' => { 'id' => claim_id } })
          expect(champva_class).to have_received(:new).with(user)
          expect(champva_instance).to have_received(:get_claim).with(claim_id)
          expect(Mobile::V0::LighthouseClaims::Proxy).not_to have_received(:new)
        end

        it 'raises error for invalid provider type' do
          expect do
            controller.send(:get_claim_from_providers, claim_id, 'invalid-provider')
          end.to raise_error(Common::Exceptions::ParameterMissing)
        end
      end
    end

    describe '#get_claim_with_provider_type' do
      let(:claim_id) { '123' }
      let(:claim_response) { { 'data' => { 'id' => claim_id } } }

      context 'with explicit provider type' do
        it 'returns hash with provider_type and claim_response' do
          proxy = double('LighthouseProxy')
          allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new).with(user).and_return(proxy)
          allow(proxy).to receive(:get_claim).with(claim_id).and_return(claim_response)

          result = controller.send(:get_claim_with_provider_type, claim_id, 'lighthouse')

          expect(result).to be_a(Hash)
          expect(result[:provider_type]).to eq('lighthouse')
          expect(result[:claim_response]).to eq(claim_response)
        end
      end

      context 'with single provider and no type specified' do
        before do
          lighthouse_class = BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider
          allow(BenefitsClaims::Providers::ProviderRegistry).to receive(:enabled_provider_classes)
            .with(user)
            .and_return([lighthouse_class])
        end

        it 'detects lighthouse provider type' do
          proxy = double('LighthouseProxy')
          allow(Mobile::V0::LighthouseClaims::Proxy).to receive(:new).with(user).and_return(proxy)
          allow(proxy).to receive(:get_claim).with(claim_id).and_return(claim_response)

          result = controller.send(:get_claim_with_provider_type, claim_id, nil)

          expect(result[:provider_type]).to eq('lighthouse')
          expect(result[:claim_response]).to eq(claim_response)
        end
      end
    end

    describe '#detect_provider_type' do
      it 'returns "lighthouse" for Lighthouse provider' do
        lighthouse_class = BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider
        result = controller.send(:detect_provider_type, lighthouse_class)

        expect(result).to eq('lighthouse')
      end

      it 'derives type from class name for other providers' do
        champva_class = double('ChampvaProvider')
        allow(champva_class).to receive(:name).and_return('BenefitsClaims::Providers::Champva::ChampvaProvider')
        allow(controller).to receive(:is_lighthouse_provider?).with(champva_class).and_return(false)

        result = controller.send(:detect_provider_type, champva_class)

        expect(result).to eq('champva')
      end
    end
  end
end
