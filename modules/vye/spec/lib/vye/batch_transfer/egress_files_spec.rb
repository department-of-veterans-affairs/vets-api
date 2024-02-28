# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::EgressFiles do
  describe '#address_changes_filename' do
    it 'returns a string' do
      expect(described_class.address_changes_filename).to be_a(String)
    end
  end

  describe '#direct_deposit_filename' do
    it 'returns a string' do
      expect(described_class.direct_deposit_filename).to be_a(String)
    end
  end

  describe '#no_change_enrollment_filename' do
    it 'returns a string' do
      expect(described_class.no_change_enrollment_filename).to be_a(String)
    end
  end
end
