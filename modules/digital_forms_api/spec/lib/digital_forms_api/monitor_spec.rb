# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/monitor'

RSpec.describe DigitalFormsApi::Monitor do
  let(:monitor) { described_class.new }

  describe '#initialize' do
    it 'initializes successfully' do
      expect(monitor).to be_a(described_class)
      expect(monitor).to be_a(Logging::Monitor)
    end
  end

  describe 'STATSD_KEY_PREFIX' do
    it 'has the correct prefix' do
      expect(described_class::STATSD_KEY_PREFIX).to eq('api.digital_forms_api')
    end
  end
end
