# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::TollExpense, type: :model do
  let(:toll_expense) do
    described_class.new(
      claim_id: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      purchase_date: Time.current,
      description: 'Bridge toll',
      cost_requested: 15.00
    )
  end

  describe 'validations' do
    it 'is valid with all required attributes' do
      expect(toll_expense).to be_valid
    end

    it 'requires a purchase_date to be present' do
      toll_expense.purchase_date = nil
      expect(toll_expense).not_to be_valid
      expect(toll_expense.errors[:purchase_date]).to include("can't be blank")
    end

    it 'requires a description to be present' do
      toll_expense.description = nil
      expect(toll_expense).not_to be_valid
    end

    it 'requires cost_requested to be present' do
      toll_expense.cost_requested = nil
      expect(toll_expense).not_to be_valid
      expect(toll_expense.errors[:cost_requested]).to include("can't be blank")
    end
  end

  describe '#expense_type' do
    it 'returns the toll constant' do
      expect(toll_expense.expense_type).to eq(TravelPay::Constants::EXPENSE_TYPES[:toll])
    end
  end

  describe 'associations' do
    it 'returns nil for claim if none is set' do
      toll_expense.claim_id = nil
      expect(toll_expense.claim).to be_nil
    end

    it 'can assign a claim object' do
      fake_claim = double('Claim', id: SecureRandom.uuid)
      toll_expense.claim = fake_claim
      expect(toll_expense.claim).to eq(fake_claim)
    end

    it 'returns receipt via receipt_association' do
      fake_receipt = double('Receipt', id: SecureRandom.uuid)
      toll_expense.receipt = fake_receipt
      expect(toll_expense.receipt_association).to eq(fake_receipt)
    end
  end

  describe '#to_h' do
    it 'includes the correct expense_type' do
      hash = toll_expense.to_h
      expect(hash['expense_type']).to eq(TravelPay::Constants::EXPENSE_TYPES[:toll])
    end
  end
end
