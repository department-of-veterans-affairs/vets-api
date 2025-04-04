# frozen_string_literal: true

require 'rails_helper'
require 'sm/configuration'

RSpec.describe SM::Configuration do
  let(:configuration) { described_class.instance }

  describe '#app_token' do
    it 'returns the app token from settings' do
      allow(Settings.mhv.sm).to receive(:app_token).and_return('test_token')
      expect(configuration.app_token).to eq('test_token')
    end
  end

  describe '#base_path' do
    context 'when use_new_api is true' do
      it 'returns the new API base path' do
        allow(Settings.mhv.sm).to receive_messages(
          use_new_api: true,
          base_path: 'mhv-sm-api-patient/v1/',
          gw_base_path: 'v1/'
        )
        allow(Settings.mhv.api_gateway.hosts).to receive(:sm_patient).and_return('https://new-api.example.com')
        expect(configuration.base_path).to eq('https://new-api.example.com/v1/')
      end
    end

    context 'when use_new_api is false' do
      it 'returns the old API base path' do
        allow(Settings.mhv.sm).to receive_messages(
          use_new_api: false,
          host: 'https://old-api.example.com',
          base_path: 'mhv-sm-api-patient/v1/',
          gw_base_path: 'v1/'
        )
        expect(configuration.base_path).to eq('https://old-api.example.com/mhv-sm-api-patient/v1/')
      end
    end
  end

  describe '#service_name' do
    it 'returns the service name' do
      expect(configuration.service_name).to eq('SM')
    end
  end
end
