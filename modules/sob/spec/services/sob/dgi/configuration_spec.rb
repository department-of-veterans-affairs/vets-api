# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SOB::DGI::Configuration do
  subject(:config) { described_class.instance }

  describe '#service_name' do
    it 'returns service name' do
      expect(config.service_name).to eq('SOB_CH33_STATUS')
    end
  end

  describe '#base_path' do
    it 'returns base path' do
      path = "#{Settings.dgi.sob.claimants.url}#{described_class::API_ROOT_PATH}"
      expect(config.base_path).to eq(path)
    end
  end

  describe '#mock_enabled?' do
    it 'returns mock enabled' do
      mock = Settings.dgi.sob.claimants.mock || false
      expect(config.mock_enabled?).to eq(mock)
    end
  end
end
