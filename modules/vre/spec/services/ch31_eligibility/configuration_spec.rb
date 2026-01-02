# frozen_string_literal: true

require 'rails_helper'

Rspec.describe VRE::Ch31Eligibility::Configuration do
  subject(:config) { described_class.instance }

  describe '#service_name' do
    it 'returns service name' do
      expect(config.service_name).to eq('RES_CH31_ELIGIBILITY')
    end
  end
end
