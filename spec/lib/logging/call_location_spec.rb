# frozen_string_literal: true

require 'rails_helper'
require 'logging/call_location'

RSpec.describe Logging::CallLocation do
  let(:call_location) { described_class.new('fake_func', 'fake_file', 'fake_line_42') }

  describe 'Logging::CallLocation' do
    it 'responds to and returns expected values' do
      expect(call_location.base_label).to eq('fake_func')
      expect(call_location.path).to eq('fake_file')
      expect(call_location.lineno).to eq('fake_line_42')
    end

    it 'returns a customized location, based on an actual location' do
      test_args = { function: call_location.base_label, file: nil, line: 42 }
      custom_cl = described_class.customize(caller_locations.first, **test_args)

      expect(custom_cl.base_label).to eq('fake_func')
      expect(custom_cl.path).to eq(caller_locations.first.path)
      expect(custom_cl.lineno).to eq(42)
    end
  end
end
