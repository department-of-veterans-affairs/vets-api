# frozen_string_literal: true

require 'rails_helper'
require 'notify/configuration'

describe Notify::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('Notify')
    end
  end
end
