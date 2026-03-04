# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::LodgingExpense, type: :model do
  let(:lodging_expense) { build(:travel_pay_lodging_expense) }

  describe 'validations' do
    it 'is valid with all required attributes from the factory' do
      expect(lodging_expense).to be_valid
    end

    it 'requires a purchase_date to be present' do
      lodging_expense.purchase_date = nil
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:purchase_date]).to include("can't be blank")
    end

    it 'allows description to be nil (inherited allow_blank: true from BaseExpense)' do
      lodging_expense.description = nil
      expect(lodging_expense).to be_valid
    end

    it 'allows description to be blank/empty string (inherited allow_blank: true from BaseExpense)' do
      lodging_expense.description = ''
      expect(lodging_expense).to be_valid
    end

    it 'requires cost_requested to be present' do
      lodging_expense.cost_requested = nil
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:cost_requested]).to include("can't be blank")
    end

    it 'requires vendor to be present and at least 1 character' do
      lodging_expense.vendor = nil
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:vendor]).to include("can't be blank")

      lodging_expense.vendor = ''
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:vendor]).to include('is too short (minimum is 1 character)')
    end

    it 'strips whitespace from vendor before validation' do
      lodging_expense.vendor = '   Marriott   '
      lodging_expense.valid?
      expect(lodging_expense.vendor).to eq('Marriott')
    end

    it 'requires check_in_date to be present' do
      lodging_expense.check_in_date = nil
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:check_in_date]).to include("can't be blank")
    end

    it 'requires check_out_date to be present' do
      lodging_expense.check_out_date = nil
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:check_out_date]).to include("can't be blank")
    end
  end

  describe 'date validations' do
    it 'skips validation if check_in_date is blank' do
      lodging_expense.check_in_date = nil
      lodging_expense.check_out_date = Time.zone.today + 1.day

      expect(lodging_expense).to be_invalid
      expect(lodging_expense.errors[:check_out_date]).not_to include('must be after check-in date')
      expect(lodging_expense.errors[:check_in_date]).to include("can't be blank")
    end

    it 'skips validation if check_out_date is blank' do
      lodging_expense.check_in_date = Time.zone.today
      lodging_expense.check_out_date = nil

      expect(lodging_expense).to be_invalid
      expect(lodging_expense.errors[:check_in_date]).not_to include('must be before check-out date')
      expect(lodging_expense.errors[:check_out_date]).to include("can't be blank")
    end

    it 'skips validation if both dates are blank' do
      lodging_expense.check_in_date = nil
      lodging_expense.check_out_date = nil

      expect(lodging_expense).to be_invalid
      expect(lodging_expense.errors[:check_in_date]).to include("can't be blank")
      expect(lodging_expense.errors[:check_out_date]).to include("can't be blank")
    end

    it 'is valid when check_out_date is after check_in_date' do
      lodging_expense.check_in_date = Time.zone.today
      lodging_expense.check_out_date = Time.zone.today + 1.day
      expect(lodging_expense).to be_valid
    end

    it 'is invalid when check_out_date is the same as check_in_date' do
      lodging_expense.check_in_date = Time.zone.today
      lodging_expense.check_out_date = Time.zone.today
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:check_out_date]).to include('must be after check-in date')
      expect(lodging_expense.errors[:check_in_date]).to include('must be before check-out date')
    end

    it 'is invalid when check_out_date is before check_in_date' do
      lodging_expense.check_in_date = Time.zone.today
      lodging_expense.check_out_date = Time.zone.today - 1.day
      expect(lodging_expense).not_to be_valid
      expect(lodging_expense.errors[:check_out_date]).to include('must be after check-in date')
      expect(lodging_expense.errors[:check_in_date]).to include('must be before check-out date')
    end
  end

  describe '#expense_type' do
    it 'returns the lodging constant' do
      expect(lodging_expense.expense_type).to eq(TravelPay::Constants::EXPENSE_TYPES[:lodging])
    end
  end

  describe 'associations' do
    it 'returns nil for claim if none is set' do
      lodging_expense.claim_id = nil
      expect(lodging_expense.claim).to be_nil
    end

    it 'can assign a claim object' do
      fake_claim = double('Claim', id: SecureRandom.uuid)
      lodging_expense.claim = fake_claim
      expect(lodging_expense.claim).to eq(fake_claim)
    end

    it 'returns receipt via receipt_association' do
      fake_receipt = { id: SecureRandom.uuid, file_name: 'test.pdf', content_type: 'application/pdf' }
      lodging_expense.receipt = fake_receipt
      expect(lodging_expense.receipt_association).to eq(fake_receipt)
    end
  end

  describe '#to_h' do
    it 'includes the correct expense_type' do
      hash = lodging_expense.to_h
      expect(hash['expense_type']).to eq(TravelPay::Constants::EXPENSE_TYPES[:lodging])
    end
  end

  describe '.permitted_params' do
    it 'extends base expense permitted parameters with lodging-specific fields' do
      params = described_class.permitted_params
      expect(params).to include(:vendor, :check_in_date, :check_out_date)
    end
  end

  describe '#to_service_params' do
    subject do
      described_class.new(
        purchase_date: Date.new(2024, 3, 15),
        description: 'Hotel stay',
        cost_requested: 150.00,
        vendor: 'Holiday Inn',
        check_in_date: Date.new(2024, 3, 15),
        check_out_date: Date.new(2024, 3, 17),
        claim_id: 'claim-uuid-789'
      )
    end

    it 'includes lodging-specific fields' do
      params = subject.to_service_params
      expect(params['vendor']).to eq('Holiday Inn')
      expect(params['check_in_date']).to eq('2024-03-15')
      expect(params['check_out_date']).to eq('2024-03-17')
    end

    it 'formats dates as ISO8601 strings' do
      params = subject.to_service_params
      expect(params['check_in_date']).to match(/\d{4}-\d{2}-\d{2}/)
      expect(params['check_out_date']).to match(/\d{4}-\d{2}-\d{2}/)
    end
  end
end
