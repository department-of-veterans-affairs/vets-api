# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/configuration'

describe VaNotify::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('VANotify')
    end
  end
end
