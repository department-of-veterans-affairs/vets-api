# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::V1::BaseClient do
  # Create a test subclass since BaseClient is meant to be inherited
  let(:test_client_class) do
    Class.new(described_class) do
      def initialize
        validate_subscription_keys!
        super()
      end

      # Expose private methods for testing
      def test_subscription_key_headers
        subscription_key_headers
      end
    end
  end

  let(:client) { test_client_class.new }

  describe '#config' do
    it 'returns the TravelClaim::Configuration singleton' do
      expect(client.config).to eq(TravelClaim::Configuration.instance)
    end
  end

  describe '#subscription_key_headers' do
    context 'in non-production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
      end

      it 'returns single subscription key header' do
        headers = client.test_subscription_key_headers

        expect(headers).to eq({ 'Ocp-Apim-Subscription-Key' => 'fake_subscription_key' })
      end
    end

    context 'in production environment' do
      let(:production_settings) do
        double(
          subscription_key: 'fake_subscription_key',
          e_subscription_key: 'e-sub-key',
          s_subscription_key: 's-sub-key'
        )
      end

      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow(Settings.check_in).to receive(:travel_reimbursement_api_v2).and_return(production_settings)
      end

      it 'returns separate E and S subscription key headers' do
        production_client = test_client_class.new
        headers = production_client.test_subscription_key_headers

        expect(headers).to eq({
                                'Ocp-Apim-Subscription-Key-E' => 'e-sub-key',
                                'Ocp-Apim-Subscription-Key-S' => 's-sub-key'
                              })
      end
    end
  end

  describe '#validate_subscription_keys!' do
    context 'when subscription key is missing in non-production' do
      let(:settings_without_key) do
        double(subscription_key: nil)
      end

      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
        allow(Settings.check_in).to receive(:travel_reimbursement_api_v2).and_return(settings_without_key)
      end

      it 'raises an error' do
        expect { test_client_class.new }.to raise_error(RuntimeError, /Missing required setting: subscription_key/)
      end
    end

    context 'when e_subscription_key is missing in production' do
      let(:settings_without_e_key) do
        double(e_subscription_key: nil, s_subscription_key: 's-key')
      end

      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow(Settings.check_in).to receive(:travel_reimbursement_api_v2).and_return(settings_without_e_key)
      end

      it 'raises an error' do
        expect { test_client_class.new }.to raise_error(RuntimeError, /Missing required setting: e_subscription_key/)
      end
    end
  end

  describe 'inheritance' do
    it 'inherits from Common::Client::Base' do
      expect(described_class.ancestors).to include(Common::Client::Base)
    end

    it 'includes Monitoring concern' do
      expect(described_class.ancestors).to include(Common::Client::Concerns::Monitoring)
    end
  end

  describe 'STATSD_KEY_PREFIX' do
    it 'is defined for metrics' do
      expect(described_class::STATSD_KEY_PREFIX).to eq('api.check_in.travel_claim')
    end
  end
end
