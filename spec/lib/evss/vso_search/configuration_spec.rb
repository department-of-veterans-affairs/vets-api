# frozen_string_literal: true

require 'rails_helper'

describe EVSS::VsoSearch::Configuration do
  describe '#base_path' do
    it 'has a base path' do
      expect(described_class.instance.base_path).to eq("#{Settings.evss.url}/wss-common-services-web-#{EVSS::VsoSearch::Configuration::API_VERSION}/rest/vsoSearch/11.0/")
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
