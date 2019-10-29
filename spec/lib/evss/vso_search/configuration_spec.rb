# frozen_string_literal: true

require 'rails_helper'

describe EVSS::VsoSearch::Configuration do
  describe '#base_path' do
    it 'has a base path' do
      base_path = "#{Settings.evss.url}/wss-common-services-web-#{Settings.evss.versions.common}/rest/vsoSearch/#{Settings.evss.versions.common}/"
      expect(described_class.instance.base_path).to eq(base_path)
    end
  end

  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('EVSS/VsoSearch')
    end
  end

  describe '#mock_enabled?' do
    it 'has a mock_enabled? method that returns a boolean' do
      expect(described_class.instance.mock_enabled?).to be_in([true, false])
    end
  end
end
