# frozen_string_literal: true

require 'rails_helper'

describe Search::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('Search/Results')
    end
  end
end
