# frozen_string_literal: true

require 'rails_helper'
require 'chip/configuration'

describe Chip::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(Chip::Configuration.instance.service_name).to eq('Chip')
    end
  end
end
