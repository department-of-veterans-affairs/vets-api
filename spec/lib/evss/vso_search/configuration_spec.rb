# frozen_string_literal: true

require 'rails_helper'

describe EVSS::VSOSearch::Configuration do
  describe '#base_path' do
    it 'has a base path' do
      version = Settings.evss.versions.common
      base_path = "#{Settings.evss.url}/wss-common-services-web-#{version}/rest/vsoSearch/#{version}/"
      expect(described_class.instance.base_path).to eq(base_path)
    end
  end

  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('EVSS/VSOSearch')
    end
  end

  describe '#mock_enabled?' do
    it 'has a mock_enabled? method that returns a boolean' do
      expect(described_class.instance.mock_enabled?).to be_in([true, false])
    end
  end
end
