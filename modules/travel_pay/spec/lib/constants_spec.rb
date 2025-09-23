# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/travel_pay/constants'

RSpec.describe TravelPay::Constants do
  describe 'EXPENSE_TYPES' do
    it 'contains the expected expense type mappings' do
      expected_types = {
        meal: 'meal',
        mileage: 'mileage',
        parking: 'parking',
        other: 'other'
      }
      expect(described_class::EXPENSE_TYPES).to eq(expected_types)
    end

    it 'is frozen' do
      expect(described_class::EXPENSE_TYPES).to be_frozen
    end
  end

  describe 'TRIP_TYPES' do
    it 'contains the expected trip type values' do
      expect(described_class::TRIP_TYPES).to eq(%w[OneWay RoundTrip Unspecified])
    end

    it 'is frozen' do
      expect(described_class::TRIP_TYPES).to be_frozen
    end
  end

  describe 'UUID_REGEX' do
    let(:valid_uuid)   { SecureRandom.uuid } # Any UUID format accepted (not limited to v4)
    let(:invalid_uuid) { 'not-a-uuid' }

    it 'matches valid UUIDs' do
      expect(described_class::UUID_REGEX.match?(valid_uuid)).to be true
    end

    it 'does not match invalid UUIDs' do
      expect(described_class::UUID_REGEX.match?(invalid_uuid)).to be false
    end

    it 'is case-insensitive' do
      uppercase_uuid = valid_uuid.upcase
      expect(described_class::UUID_REGEX.match?(uppercase_uuid)).to be true
    end
  end
end
