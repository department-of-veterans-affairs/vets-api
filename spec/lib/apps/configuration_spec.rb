# frozen_string_literal: true

require 'rails_helper'
require 'apps/configuration'

describe Apps::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('APPS')
    end
  end

  describe '#base_path' do
    it 'returns the base path for the given environment' do
      allow(Settings.directory).to receive(:url).and_return('boop')
      expect(described_class.instance.base_path).to eq('boop')
    end
  end
end
