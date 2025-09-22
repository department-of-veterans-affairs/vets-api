# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/travel_pay/constants'

RSpec.describe TravelPay::Constants do
  describe 'BASE_EXPENSE_PATHS' do
    it 'includes the expected expense types' do
      expect(described_class::BASE_EXPENSE_PATHS.keys).to contain_exactly(
        :meal, :mileage, :parking, :other
      )
    end

    it 'maps expense types to correct API paths' do
      expect(described_class::BASE_EXPENSE_PATHS[:meal]).to eq('api/v1/expenses/meal')
      expect(described_class::BASE_EXPENSE_PATHS[:mileage]).to eq('api/v2/expenses/mileage')
      expect(described_class::BASE_EXPENSE_PATHS[:parking]).to eq('api/v1/expenses/parking')
      expect(described_class::BASE_EXPENSE_PATHS[:other]).to eq('api/v1/expenses/other')
    end

    it 'is frozen' do
      expect(described_class::BASE_EXPENSE_PATHS).to be_frozen
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
