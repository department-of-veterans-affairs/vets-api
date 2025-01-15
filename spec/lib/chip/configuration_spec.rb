# frozen_string_literal: true

require 'rails_helper'
require 'chip/configuration'

describe Chip::Configuration do
  subject { described_class.instance }

  describe '#settings' do
    it 'is of type settings' do
      expect(subject.settings).to be_a(Config::Options)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(subject.service_name).to eq('Chip')
    end
  end

  describe '#url' do
    it 'has a server url' do
      expect(subject.url).to eq(Settings.chip.url)
    end
  end

  describe '#api_gtwy_id' do
    it 'has a api gateway id' do
      expect(subject.api_gtwy_id).to eq(Settings.chip.api_gtwy_id)
    end
  end

  describe '#base_path' do
    it 'has the base_path' do
      expect(subject.base_path).to eq(Settings.chip.base_path)
    end
  end

  describe '#connection' do
    it 'has a connection' do
      expect(subject.connection).to be_an_instance_of(Faraday::Connection)
    end
  end

  describe '#valid_tenant?' do
    let(:tenant_name) { 'mobile_app' }
    let(:tenant_id) { Settings.chip[tenant_name].tenant_id }

    context 'when invalid tenant_name' do
      it 'returns false for non-existent tenant_name' do
        expect(subject.valid_tenant?(tenant_name: 'abc', tenant_id:)).to be(false)
      end

      it 'returns false for nil tenant_name' do
        expect(subject.valid_tenant?(tenant_name: nil, tenant_id:)).to be(false)
      end
    end

    context 'when invalid tenant_id' do
      it 'returns false for non-matching tenant_id' do
        expect(subject.valid_tenant?(tenant_name:, tenant_id: 'def')).to be(false)
      end

      it 'returns false for nil tenant_id' do
        expect(subject.valid_tenant?(tenant_name:, tenant_id: nil)).to be(false)
      end
    end

    context 'when valid tenant parameters' do
      it 'returns true' do
        expect(subject.valid_tenant?(tenant_name:, tenant_id:)).to be(true)
      end
    end
  end
end
