# frozen_string_literal: true

require 'rails_helper'
require 'rx/configuration'

RSpec.describe Rx::Configuration do
  let(:configuration) { described_class.instance }

  describe '#app_token' do
    it 'returns the app token from settings' do
      allow(Settings.mhv.rx).to receive(:app_token).and_return('test_token')
      expect(configuration.app_token).to eq('test_token')
    end
  end

  describe '#app_token_va_gov' do
    it 'returns the VA.gov app token from settings' do
      allow(Settings.mhv.rx).to receive(:app_token_va_gov).and_return('va_gov_token')
      expect(configuration.app_token_va_gov).to eq('va_gov_token')
    end
  end

  describe '#base_path' do
    context 'when use_new_api is true' do
      it 'returns the new API base path' do
        allow(Settings.mhv.rx).to receive_messages(
          use_new_api: true,
          base_path: 'mhv-api-patient/v1/',
          gw_base_path: 'v1/'
        )
        allow(Settings.mhv.api_gateway.hosts).to receive(:pharmacy).and_return('https://new-api.example.com')
        expect(configuration.base_path).to eq('https://new-api.example.com/v1/')
      end
    end

    context 'when use_new_api is false' do
      it 'returns the old API base path' do
        allow(Settings.mhv.rx).to receive_messages(
          use_new_api: false,
          host: 'https://old-api.example.com',
          base_path: 'mhv-api-patient/v1/',
          gw_base_path: 'v1/'
        )
        expect(configuration.base_path).to eq('https://old-api.example.com/mhv-api-patient/v1/')
      end
    end
  end

  describe '#caching_enabled?' do
    it 'returns true if collection caching is enabled' do
      allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(true)
      expect(configuration.caching_enabled?).to be true
    end

    it 'returns false if collection caching is not enabled' do
      allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(false)
      expect(configuration.caching_enabled?).to be false
    end
  end

  describe '#service_name' do
    it 'returns the service name' do
      expect(configuration.service_name).to eq('Rx')
    end
  end

  describe '#breakers_error_threshold' do
    it 'returns the error threshold for breakers' do
      expect(configuration.breakers_error_threshold).to eq(80)
    end
  end
end
