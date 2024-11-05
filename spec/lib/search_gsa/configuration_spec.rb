# frozen_string_literal: true

require 'rails_helper'

describe SearchGsa::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('Search/Results')
    end
  end

  describe '#base_path' do
    it 'provides api.gsa.gov search URL' do
      expect(described_class.instance.base_path).to eq('https://api.gsa.gov/technology/searchgov/v2/results/i14y')
    end
  end
end
