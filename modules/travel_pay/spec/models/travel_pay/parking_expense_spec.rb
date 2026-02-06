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

    it 'allows description to be nil (inherited allow_blank: true from BaseExpense)' do
      parking_expense.description = nil
      expect(parking_expense).to be_valid
    end

    it 'allows description to be blank/empty string (inherited allow_blank: true from BaseExpense)' do
      parking_expense.description = ''
      expect(parking_expense).to be_valid
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
      fake_receipt = { id: SecureRandom.uuid, file_name: 'test.pdf', content_type: 'application/pdf' }
      parking_expense.receipt = fake_receipt
      expect(parking_expense.receipt_association).to eq(fake_receipt)
    end
  end

  describe '#to_h' do
    it 'includes the correct expense_type' do
      hash = parking_expense.to_h
      expect(hash['expense_type']).to eq(TravelPay::Constants::EXPENSE_TYPES[:parking])
    end
  end

  describe '.permitted_params' do
    it 'inherits base expense permitted parameters' do
      params = described_class.permitted_params
      expect(params).to eq(TravelPay::BaseExpense.permitted_params)
    end
  end

  describe '#to_service_params' do
    subject do
      described_class.new(
        purchase_date: Date.new(2024, 3, 15),
        description: 'Parking at hospital',
        cost_requested: 10.00,
        claim_id: 'claim-uuid-parking'
      )
    end

    it 'returns correct expense_type' do
      params = subject.to_service_params
      expect(params['expense_type']).to eq('parking')
    end
  end
end
