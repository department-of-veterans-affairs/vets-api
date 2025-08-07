# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TravelPay::BaseExpense Factory', type: :model do
  describe 'travel_pay_base_expense factory' do
    it 'creates a valid BaseExpense instance' do
      expense = FactoryBot.build(:travel_pay_base_expense)
      expect(expense).to be_a(TravelPay::BaseExpense)
      expect(expense).to be_valid
      expect(expense.description).to eq('Travel expense')
      expect(expense.cost_requested).to eq(100.00)
    end

    it 'creates an expense with claim_id trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :with_claim_id)
      expect(expense.claim_id).to be_present
      expect(expense.claim_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
    end

    it 'creates an expense with receipt trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :with_receipt)
      expect(expense.receipt).to be_present
      expect(expense.as_json['has_receipt']).to be true
    end

    it 'creates a hotel expense with trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :hotel_expense)
      expect(expense.description).to eq('Hotel accommodation')
      expect(expense.cost_requested).to eq(150.00)
    end

    it 'creates a meal expense with trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :meal_expense)
      expect(expense.description).to eq('Meal expense')
      expect(expense.cost_requested).to eq(45.75)
    end

    it 'creates a transportation expense with trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :transportation_expense)
      expect(expense.description).to eq('Taxi fare')
      expect(expense.cost_requested).to eq(25.50)
    end

    it 'creates a high cost expense with trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :high_cost)
      expect(expense.cost_requested).to eq(500.00)
    end

    it 'creates a minimal cost expense with trait' do
      expense = FactoryBot.build(:travel_pay_base_expense, :minimal_cost)
      expect(expense.cost_requested).to eq(1.00)
    end
  end
end
