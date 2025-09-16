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

  describe '#x_api_key' do
    it 'returns the API GW key from settings' do
      allow(Settings.mhv.rx).to receive(:x_api_key).and_return('test_api_key')
      expect(configuration.x_api_key).to eq('test_api_key')
    end
  end

  describe '#base_path' do
    it 'returns the API gateway base path' do
      allow(Settings.mhv.api_gateway.hosts).to receive(:pharmacy).and_return('https://api-gateway.example.com')
      allow(Settings.mhv.rx).to receive(:gw_base_path).and_return('v1/')
      expect(configuration.base_path).to eq('https://api-gateway.example.com/v1/')
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
