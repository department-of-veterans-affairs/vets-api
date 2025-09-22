# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ParkingExpense, type: :model do
  let(:parking_expense) do
    described_class.new(
      claim_id: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      purchase_date: Time.current,
      description: 'Parking at airport',
      cost_requested: 15.00
    )
  end

  describe 'validations' do
    it 'is valid with all required attributes' do
      expect(parking_expense).to be_valid
    end

    it 'requires a purchase_date to be present' do
      parking_expense.purchase_date = nil
      expect(parking_expense).not_to be_valid
      expect(parking_expense.errors[:purchase_date]).to include("can't be blank")
    end

    it 'requires a description to be present' do
      parking_expense.description = nil
      expect(parking_expense).not_to be_valid
    end

    it 'requires cost_requested to be present' do
      parking_expense.cost_requested = nil
      expect(parking_expense).not_to be_valid
      expect(parking_expense.errors[:cost_requested]).to include("can't be blank")
    end
  end

  describe '#expense_type' do
    it 'returns the parking constant' do
      expect(parking_expense.expense_type).to eq(TravelPay::Constants::EXPENSE_TYPES[:parking])
    end
  end

  describe 'associations' do
    it 'returns nil for claim if none is set' do
      parking_expense.claim_id = nil
      expect(parking_expense.claim).to be_nil
    end

    it 'can assign a claim object' do
      fake_claim = double('Claim', id: SecureRandom.uuid)
      parking_expense.claim = fake_claim
      expect(parking_expense.claim).to eq(fake_claim)
    end

    it 'returns receipt via receipt_association' do
      fake_receipt = double('Receipt', id: SecureRandom.uuid)
      parking_expense.receipt = fake_receipt
      expect(parking_expense.receipt_association).to eq(fake_receipt)
    end
  end
end
