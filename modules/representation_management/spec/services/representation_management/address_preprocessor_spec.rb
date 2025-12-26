# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AddressPreprocessor do
  describe '.clean' do
    it 'extracts room into address_line2' do
      addr = { 'address_line1' => '11000 Wilshire Blvd., Rm 509', 'address_line2' => nil }
      cleaned = described_class.clean(addr)
      expect(cleaned['address_line1']).to eq('11000 Wilshire Blvd.')
      expect(cleaned['address_line2']).to eq('Rm 509')
    end

    it 'extracts PO Box and removes prefix' do
      addr = { 'address_line1' => '123 Main St Suite 5 PO Box 100', 'address_line2' => nil }
      cleaned = described_class.clean(addr)
      expect(cleaned['address_line1'].downcase).to include('po box 100')
      expect(cleaned['address_line2']).to be_nil
    end

    it 'returns original when no changes' do
      addr = { 'address_line1' => '123 East Main St', 'address_line2' => 'Suite 2' }
      expect(described_class.clean(addr)).to eq(addr)
    end

    it 'returns PO Box only when room and PO Box present' do
      addr = { 'address_line1' => 'PO Box 123, Rm 5', 'address_line2' => nil }
      cleaned = described_class.clean(addr)
      expect(cleaned['address_line1']).to eq('PO Box 123')
      expect(cleaned['address_line2']).to be_nil
    end

    it 'returns nil address lines when only room is present' do
      addr = { 'address_line1' => 'Rm 5', 'address_line2' => nil }
      cleaned = described_class.clean(addr)
      expect(cleaned['address_line1']).to be_nil
      expect(cleaned['address_line2']).to be_nil
    end
  end
end
