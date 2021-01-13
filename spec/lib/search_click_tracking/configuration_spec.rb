# frozen_string_literal: true

require 'rails_helper'

describe SearchClickTracking::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('SearchClickTracking')
    end
  end
end
