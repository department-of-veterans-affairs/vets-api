# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ExpenseNormalizer do
  # Create a dummy class to include the module
  let(:normalizer) do
    Class.new do
      include TravelPay::ExpenseNormalizer
    end.new
  end

  describe '#normalize_expense' do
    it 'returns non-hash inputs unchanged' do
      expect(normalizer.normalize_expense(nil)).to be_nil
      expect(normalizer.normalize_expense('string')).to eq('string')
      expect(normalizer.normalize_expense(123)).to eq(123)
    end

    it 'normalizes Parking expenseType using name' do
      expense = {
        'expenseType' => 'Other',
        'name' => 'Parking'
      }

      normalizer.normalize_expense(expense)

      expect(expense['expenseType']).to eq('Parking')
    end

    it 'does not override correctly cased reasonNotUsingPOV' do
      expense = {
        'reasonNotUsingPOV' => 'Other'
      }

      normalizer.normalize_expense(expense)

      expect(expense['reasonNotUsingPOV']).to eq('Other')
      expect(expense.keys).to contain_exactly('reasonNotUsingPOV')
    end
  end

  describe '#normalize_expenses' do
    it 'normalizes each expense in the array' do
      expenses = [
        { 'name' => 'Parking', 'expenseType' => 'Other' }
      ]

      normalizer.normalize_expenses(expenses)

      expect(expenses[0]['expenseType']).to eq('Parking')
    end

    it 'returns non-array inputs unchanged' do
      expect(normalizer.normalize_expenses(nil)).to be_nil
      expect(normalizer.normalize_expenses({})).to eq({})
    end

    it 'normalizes CamelCase reasonNotUsingPOV for CommonCarrier expenses' do
      expense = {
        'expenseType' => 'CommonCarrier',
        'reasonNotUsingPOV' => 'PrivatelyOwnedVehicleNotAvailable'
      }

      normalizer.normalize_expense(expense)

      expect(expense['reasonNotUsingPOV'])
        .to eq('Privately Owned Vehicle Not Available')
    end

    it 'normalizes snake_case reasonNotUsingPOV for CommonCarrier expenses' do
      expense = {
        'expenseType' => 'CommonCarrier',
        'reasonNotUsingPOV' => 'medically_indicated'
      }

      normalizer.normalize_expense(expense)

      expect(expense['reasonNotUsingPOV']).to eq('Medically Indicated')
    end

    it 'does not change already normalized CommonCarrier values' do
      expense = {
        'expenseType' => 'CommonCarrier',
        'reasonNotUsingPOV' => 'Other'
      }

      normalizer.normalize_expense(expense)

      expect(expense['reasonNotUsingPOV']).to eq('Other')
    end

    it 'does not normalize reasonNotUsingPOV for non-CommonCarrier expenses' do
      expense = {
        'expenseType' => 'Mileage',
        'reasonNotUsingPOV' => 'PrivatelyOwnedVehicleNotAvailable'
      }

      normalizer.normalize_expense(expense)

      expect(expense['reasonNotUsingPOV'])
        .to eq('PrivatelyOwnedVehicleNotAvailable')
    end

    it 'returns the original value when normalization key is unknown' do
      expense = {
        'expenseType' => 'CommonCarrier',
        'reasonNotUsingPOV' => 'TotallyUnknownValue'
      }

      normalizer.normalize_expense(expense)

      expect(expense['reasonNotUsingPOV']).to eq('TotallyUnknownValue')
    end
  end
end
