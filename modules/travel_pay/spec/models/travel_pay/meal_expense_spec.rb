# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::MealExpense, type: :model do
  let(:meal_expense) { build(:travel_pay_meal_expense) }
  let(:meal_expense_with_claim) { build(:travel_pay_meal_expense, :with_claim_id) }

  describe 'validations' do
    it 'is valid with all required attributes' do
      expect(meal_expense).to be_valid
    end

    it 'requires a purchase_date to be present' do
      meal_expense.purchase_date = nil
      expect(meal_expense).not_to be_valid
      expect(meal_expense.errors[:purchase_date]).to include("can't be blank")
    end

    it 'requires a description to be present' do
      meal_expense.description = nil
      expect(meal_expense).not_to be_valid
      expect(meal_expense.errors[:description]).to include("can't be blank")
    end

    it 'requires cost_requested to be present' do
      meal_expense.cost_requested = nil
      expect(meal_expense).not_to be_valid
      expect(meal_expense.errors[:cost_requested]).to include("can't be blank")
    end

    it 'requires vendor_name to be present and not just whitespace' do
      meal_expense.vendor_name = ''
      expect(meal_expense).not_to be_valid

      meal_expense.vendor_name = '   '
      expect(meal_expense).not_to be_valid
    end
  end

  describe '#expense_type' do
    it 'returns the meal constant' do
      expect(meal_expense.expense_type).to eq(TravelPay::Constants::EXPENSE_TYPES[:meal])
    end
  end

  describe 'associations' do
    it 'returns nil for claim if none is set' do
      meal_expense.claim_id = nil
      expect(meal_expense.claim).to be_nil
    end

    it 'can assign a claim object' do
      fake_claim = double('Claim', id: SecureRandom.uuid)
      meal_expense.claim = fake_claim
      expect(meal_expense.claim).to eq(fake_claim)
    end

    it 'returns receipt via receipt_association' do
      fake_receipt = double('Receipt', id: SecureRandom.uuid)
      meal_expense.receipt = fake_receipt
      expect(meal_expense.receipt_association).to eq(fake_receipt)
    end
  end

  describe '#to_h' do
    it 'includes the correct expense_type' do
      hash = meal_expense.to_h
      expect(hash['expense_type']).to eq(TravelPay::Constants::EXPENSE_TYPES[:meal])
    end
  end
end
