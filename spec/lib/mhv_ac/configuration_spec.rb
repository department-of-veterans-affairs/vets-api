# frozen_string_literal: true

require 'rails_helper'
require 'mhv_ac/configuration'

# rubocop:disable RSpec/SpecFilePathFormat
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
# rubocop:enable RSpec/SpecFilePathFormat
