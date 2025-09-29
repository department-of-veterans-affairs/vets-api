# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::AddressPreprocessor do
  describe '.clean' do
    it 'extracts room into address_line2' do
      addr = { 'address_line1' => '11000 Wilshire Blvd., Rm 509', 'address_line2' => nil }
      cleaned = described_class.clean(addr)
      expect(cleaned['address_line1']).to eq('11000 Wilshire Blvd.')
      expect(cleaned['address_line2']).to eq('Rm 509')
    end

    it 'extracts PO Box and moves prefix to line2' do
      addr = { 'address_line1' => 'DAV- VARO PO Box 25126', 'address_line2' => nil }
      cleaned = described_class.clean(addr)
      expect(cleaned['address_line1'].downcase).to include('po box 25126')
      expect(cleaned['address_line2']).to match(/DAV-? VARO/i)
    end

    it 'returns original when no changes' do
      addr = { 'address_line1' => '123 East Main St', 'address_line2' => 'Suite 2' }
      expect(described_class.clean(addr)).to eq(addr)
    end
  end
end
