# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ReferenceData::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('Vet360/ReferenceData')
    end
  end
end
