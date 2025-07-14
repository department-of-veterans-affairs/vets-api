# frozen_string_literal: true

require 'rails_helper'
require 'mhv_ac/configuration'

# rubocop:disable Rspec/SpecFilePathFormat
RSpec.describe MHVAC::Configuration do
  let(:configuration) { described_class.instance }

  describe '#app_token' do
    it 'returns the app token from settings' do
      allow(Settings.mhv.rx).to receive(:app_token).and_return('test_token')
      expect(configuration.app_token).to eq('test_token')
    end
  end

  describe '#x_api_key' do
    it 'returns the API GW key from settings' do
      allow(Settings.mhv.rx).to receive(:x_api_key).and_return('test_api_key')
      expect(configuration.x_api_key).to eq('test_api_key')
    end
  end

  describe '#base_path' do
    context 'when Flipper is enabled for API gateway' do
      it 'returns the API gateway base path' do
        allow(Flipper).to receive(:respond_to?).with(:enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(true)
        allow(Settings.mhv.api_gateway.hosts).to receive(:pharmacy).and_return('https://api-gateway.example.com')
        allow(Settings.mhv.rx).to receive(:gw_base_path).and_return('v1/')
        expect(configuration.base_path).to eq('https://api-gateway.example.com/v1/')
      end
    end

    context 'when flipper is not enabled (bootup)' do
      it 'returns the default base path' do
        allow(Flipper).to receive(:respond_to?).with(:enabled).and_return(false)
        allow(Settings.mhv.rx).to receive_messages(
          host: 'https://default-api.example.com',
          base_path: 'mhv-api-patient/v1/'
        )
        expect(configuration.base_path).to eq('https://default-api.example.com/mhv-api-patient/v1/')
      end
    end

    context 'when Flipper is disabled for API gateway' do
      it 'returns the default base path' do
        allow(Flipper).to receive(:respond_to?).with(:enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(false)
        allow(Settings.mhv.rx).to receive_messages(
          host: 'https://default-api.example.com',
          base_path: 'mhv-api-patient/v1/'
        )
        expect(configuration.base_path).to eq('https://default-api.example.com/mhv-api-patient/v1/')
      end
    end

    context 'when a NoMethodError occurs' do
      it 'logs the error and returns the default base path' do
        allow(Flipper).to receive(:respond_to?).with(:enabled).and_return(true)
        allow(Flipper)
          .to receive(:enabled?)
          .with(:mhv_secure_messaging_migrate_to_api_gateway)
          .and_raise(NoMethodError, 'undefined method')

        allow(Settings.mhv.rx).to receive_messages(
          host: 'https://error-api.example.com',
          base_path: 'mhv-api-patient/v1/'
        )
        expect(Rails.logger).to receive(:error).with(/RX:Configuration Flipper error: undefined method/)
        expect(configuration.base_path).to eq('https://error-api.example.com/mhv-api-patient/v1/')
      end
    end
  end

  describe '#service_name' do
    it 'returns the service name' do
      expect(configuration.service_name).to eq('MHVAcctCreation')
    end
  end

  describe '#breakers_error_threshold' do
    it 'returns the error threshold for breakers' do
      expect(configuration.breakers_error_threshold).to eq(50)
    end
  end
end
# rubocop:enable Rspec/SpecFilePathFormat
