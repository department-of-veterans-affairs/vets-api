# frozen_string_literal: true

require 'rails_helper'

describe EVSS::ReferenceData::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('EVSS/AWS/ReferenceData')
    end
  end

  describe '#mock_enabled?' do
    it 'has a mock_enabled? method that returns a boolean' do
      expect(Appeals::Configuration.instance.mock_enabled?).to be_in([true, false])
    end
  end
end
