# frozen_string_literal: true

require 'rails_helper'

describe Search::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('Search/Results')
    end
  end

  describe '#base_path' do
    it 'provides search.usa.gov search URL' do
      expect(described_class.instance.base_path).to eq('https://search.usa.gov/api/v2/search/i14y')
    end
  end
end
