# frozen_string_literal: true

require 'rails_helper'
require 'chip/configuration'

describe Chip::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(Chip::Configuration.instance.service_name).to eq('Chip')
    end
  end

  describe '#server_url' do
    it 'has a server url' do
      expect(Chip::Configuration.instance.server_url).to eq("#{Settings.chip.url}/#{Settings.chip.base_path}")
    end
  end

  describe '#api_gtwy_id' do
    it 'has a api gateway id' do
      expect(Chip::Configuration.instance.api_gtwy_id).to eq(Settings.chip.api_gtwy_id)
    end
  end

  describe '#connection' do
    it 'has a connection' do
      expect(Chip::Configuration.instance.connection).to be_an_instance_of(Faraday::Connection)
    end
  end

  describe '#valid_tenant?' do
    let(:test_tenant_name) { 'mobile_app' }
    let(:test_tenant_id) { '6f1c8b41-9c77-469d-852d-269c51a7d380' }

    it 'returns false for invalid tenant_name' do
      expect(Chip::Configuration.instance.valid_tenant?(tenant_name: 'test_tenant_name',
                                                        tenant_id: test_tenant_id)).to eq(false)
    end

    it 'returns false for nil tenant_name' do
      expect(Chip::Configuration.instance.valid_tenant?(tenant_name: nil,
                                                        tenant_id: test_tenant_id)).to eq(false)
    end

    it 'returns false for invalid tenant_id' do
      expect(Chip::Configuration.instance.valid_tenant?(tenant_name: test_tenant_name,
                                                        tenant_id: 'test_tenant_id')).to eq(false)
    end

    it 'returns false for nil tenant_id' do
      expect(Chip::Configuration.instance.valid_tenant?(tenant_name: test_tenant_name,
                                                        tenant_id: nil)).to eq(false)
    end

    it 'returns true for valid tenant parameters' do
      expect(Chip::Configuration.instance.valid_tenant?(tenant_name: test_tenant_name,
                                                        tenant_id: test_tenant_id)).to eq(true)
    end
  end
end
