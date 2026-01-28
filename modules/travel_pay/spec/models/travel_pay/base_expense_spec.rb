# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::BaseExpense, type: :model do
  let(:valid_attributes) do
    {
      description: 'General expense',
      cost_requested: 100.00,
      purchase_date: Time.current
    }
  end

  describe 'ActiveModel functionality' do
    it 'includes ActiveModel::Model' do
      expect(described_class.ancestors).to include(ActiveModel::Model)
    end

    it 'includes ActiveModel::Attributes' do
      expect(described_class.ancestors).to include(ActiveModel::Attributes)
    end

    it 'includes ActiveModel::Validations' do
      expect(described_class.ancestors).to include(ActiveModel::Validations)
    end
  end

  describe 'attributes' do
    subject { described_class.new }

    it 'has a receipt attribute with default nil' do
      expect(subject.receipt).to be_nil
    end

    it 'has a purchase_date datetime attribute' do
      expect(subject).to respond_to(:purchase_date)
      expect(subject).to respond_to(:purchase_date=)
    end

    it 'has a description string attribute' do
      expect(subject).to respond_to(:description)
      expect(subject).to respond_to(:description=)
    end

    it 'has a cost_requested float attribute' do
      expect(subject).to respond_to(:cost_requested)
      expect(subject).to respond_to(:cost_requested=)
    end

    it 'has a claim_id string attribute' do
      expect(subject).to respond_to(:claim_id)
      expect(subject).to respond_to(:claim_id=)
    end
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    context 'with valid attributes' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'purchase_date validation' do
      it 'requires purchase_date to be present' do
        subject.purchase_date = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:purchase_date]).to include("can't be blank")
      end
    end

    context 'description validation' do
      it 'allows description to be nil' do
        subject.description = nil
        expect(subject).to be_valid
        expect(subject.errors[:description]).to be_empty
      end

      it 'allows description to be blank/empty string' do
        subject.description = ''
        expect(subject).to be_valid
        expect(subject.errors[:description]).to be_empty
      end

      it 'requires description to be 2000 characters or less when present' do
        subject.description = 'a' * 2001
        expect(subject).not_to be_valid
        expect(subject.errors[:description]).to include('is too long (maximum is 2000 characters)')
      end

      it 'allows description of exactly 2000 characters' do
        subject.description = 'a' * 2000
        expect(subject).to be_valid
      end
    end

    context 'cost_requested validation' do
      it 'requires cost_requested to be present' do
        subject.cost_requested = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:cost_requested]).to include("can't be blank")
      end

      it 'requires cost_requested to be greater than 0' do
        subject.cost_requested = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:cost_requested]).to include('must be greater than 0')
      end

      it 'requires cost_requested to be greater than 0 (negative value)' do
        subject.cost_requested = -10.50
        expect(subject).not_to be_valid
        expect(subject.errors[:cost_requested]).to include('must be greater than 0')
      end

      it 'allows positive cost_requested values' do
        subject.cost_requested = 25.99
        expect(subject).to be_valid
      end
    end
  end

  describe 'claim association' do
    subject { described_class.new(valid_attributes) }

    let(:mock_claim) { double('Claim', id: 'claim-uuid-123') }

    describe '#claim' do
      context 'when claim_id is nil' do
        it 'returns nil' do
          expect(subject.claim).to be_nil
        end
      end

      context 'when claim_id is set' do
        let(:expense_with_claim) { described_class.new(valid_attributes.merge(claim_id: 'claim-uuid-123')) }

        before do
          allow(expense_with_claim).to receive(:find_claim_by_id).with('claim-uuid-123').and_return(mock_claim)
        end

        it 'returns the associated claim' do
          expect(expense_with_claim.claim).to eq(mock_claim)
        end

        it 'memoizes the claim' do
          expense_with_claim.claim
          expect(expense_with_claim).to receive(:find_claim_by_id).exactly(0).times
          expense_with_claim.claim
        end
      end
    end

    describe '#claim=' do
      it 'sets the claim and extracts the ID' do
        subject.claim = mock_claim
        expect(subject.instance_variable_get(:@claim)).to eq(mock_claim)
        expect(subject.claim_id).to eq('claim-uuid-123')
      end

      it 'handles nil claim objects' do
        subject.claim = nil
        expect(subject.instance_variable_get(:@claim)).to be_nil
        expect(subject.claim_id).to be_nil
      end
    end
  end

  describe 'receipt association' do
    subject { described_class.new(valid_attributes) }

    let(:mock_receipt) { double('Receipt', id: 'receipt-uuid-456') }

    describe '#receipt_association' do
      it 'returns the receipt attribute' do
        subject.receipt = mock_receipt
        expect(subject.receipt_association).to eq(mock_receipt)
      end

      it 'returns nil when no receipt is set' do
        expect(subject.receipt_association).to be_nil
      end
    end

    describe '#receipt=' do
      it 'sets the receipt attribute' do
        subject.receipt = mock_receipt
        expect(subject.receipt).to eq(mock_receipt)
      end
    end

    describe '#receipt?' do
      it 'returns false when no receipt is set' do
        expect(subject.receipt?).to be false
      end

      it 'returns true when receipt is present' do
        subject.receipt = mock_receipt
        expect(subject.receipt?).to be true
      end

      it 'returns false when receipt is nil' do
        subject.receipt = nil
        expect(subject.receipt?).to be false
      end

      it 'returns false when receipt is empty string' do
        subject.receipt = ''
        expect(subject.receipt?).to be false
      end
    end
  end

  describe '#to_h' do
    subject { described_class.new(valid_attributes.merge(claim_id: 'claim-123')) }

    it 'returns a hash representation including core attributes' do
      json = subject.to_h
      expect(json['description']).to eq('General expense')
      expect(json['cost_requested']).to eq(100.00)
      expect(json['claim_id']).to eq('claim-123')
    end

    it 'includes has_receipt flag when receipt is nil' do
      json = subject.to_h
      expect(json['has_receipt']).to be false
    end

    it 'does not include receipt key when receipt is nil' do
      json = subject.to_h
      expect(json).not_to have_key('receipt')
    end

    it 'includes has_receipt flag when receipt is present' do
      subject.receipt = { file_name: 'test', file_data: 'data', content_type: 'type', length: 123 }
      json = subject.to_h
      expect(json['has_receipt']).to be true
    end

    it 'includes receipt when receipt is present' do
      mock_receipt = { file_name: 'test', file_data: 'data', content_type: 'type', length: 123 }
      expected_receipt_data = { fileName: 'test', fileData: 'data', contentType: 'type',
                                length: 123 }.with_indifferent_access
      subject.receipt = mock_receipt
      json = subject.to_h
      expect(json['receipt']).to eq(expected_receipt_data)
    end
  end

  describe '#expense_type' do
    subject { described_class.new(valid_attributes) }

    it 'returns "other" as the default expense type' do
      expect(subject.expense_type).to eq('other')
    end
  end

  describe 'inheritance support' do
    let(:custom_expense_class) do
      Class.new(described_class) do
        def expense_type
          'custom'
        end

        def custom_calculation
          cost_requested * 1.1
        end

        def custom_method
          'extended functionality'
        end

        def self.name
          'CustomExpense'
        end
      end
    end

    let(:hotel_expense_class) do
      Class.new(described_class) do
        def expense_type
          'hotel'
        end

        def hotel_specific_method
          'hotel specific logic'
        end

        def self.name
          'HotelExpense'
        end
      end
    end

    it 'allows subclasses to override expense_type' do
      custom_expense = custom_expense_class.new(valid_attributes)
      expect(custom_expense.expense_type).to eq('custom')
    end

    it 'allows subclasses to add custom calculation methods' do
      custom_expense = custom_expense_class.new(valid_attributes)
      expect(custom_expense.custom_calculation).to be_within(0.01).of(110.0)
    end

    it 'supports multiple inheritance scenarios' do
      hotel_expense = hotel_expense_class.new(valid_attributes)
      expect(hotel_expense.expense_type).to eq('hotel')
      expect(hotel_expense.hotel_specific_method).to eq('hotel specific logic')
      expect(hotel_expense).to be_valid
    end

    it 'allows subclasses to add additional methods' do
      custom_expense = custom_expense_class.new(valid_attributes)
      expect(custom_expense.custom_method).to eq('extended functionality')
    end

    it 'inherits all validations' do
      custom_expense = custom_expense_class.new
      custom_expense.valid?
      # description allows nil, so no error when nil
      expect(custom_expense.errors[:description]).to be_empty
      expect(custom_expense.errors[:cost_requested]).to include("can't be blank")
      expect(custom_expense.errors[:purchase_date]).to include("can't be blank")
    end

    it 'maintains ActiveModel functionality in subclasses' do
      custom_expense = custom_expense_class.new(valid_attributes)
      json = custom_expense.to_h
      expect(json['expense_type']).to eq('custom')
      expect(json['description']).to eq('General expense')
      expect(json['cost_requested']).to eq(100.00)
    end
  end

  describe 'instantiation scenarios' do
    context 'creating a basic expense' do
      let(:expense) do
        described_class.new(
          description: 'Generic expense',
          cost_requested: 50.00,
          purchase_date: Date.current
        )
      end

      it 'creates a valid expense' do
        expect(expense).to be_valid
        expect(expense.description).to eq('Generic expense')
        expect(expense.cost_requested).to eq(50.00)
        expect(expense.expense_type).to eq('other')
      end
    end

    context 'creating an expense with claim association' do
      let(:expense) do
        described_class.new(
          description: 'Expense with claim',
          cost_requested: 75.00,
          purchase_date: Date.current,
          claim_id: 'uuid-123'
        )
      end

      it 'creates a valid expense with claim_id' do
        expect(expense).to be_valid
        expect(expense.claim_id).to eq('uuid-123')
      end
    end

    context 'creating an expense with receipt' do
      let(:mock_receipt) { { file_name: 'test', file_data: 'data', content_type: 'type', length: 123 } }
      let(:expense) do
        described_class.new(
          description: 'Expense with receipt',
          cost_requested: 25.00,
          purchase_date: Date.current,
          receipt: mock_receipt
        )
      end

      it 'creates a valid expense with receipt' do
        expect(expense).to be_valid
        expect(expense.receipt).to eq(mock_receipt)
        expect(expense.to_h['has_receipt']).to be true
      end
    end
  end

  describe 'private methods' do
    subject { described_class.new(valid_attributes) }

    describe '#find_claim_by_id' do
      it 'logs a debug message and returns nil (safe default)' do
        expect(Rails.logger).to receive(:debug)
        result = subject.send(:find_claim_by_id, 'test-id')
        expect(result).to be_nil
      end
    end

    describe '#format_date' do
      it 'formats Date objects as ISO8601 strings' do
        date = Date.new(2024, 3, 15)
        result = subject.send(:format_date, date)
        expect(result).to eq('2024-03-15')
      end

      it 'formats DateTime objects as ISO8601 strings' do
        datetime = DateTime.new(2024, 3, 15, 14, 30, 0)
        result = subject.send(:format_date, datetime)
        expect(result).to eq('2024-03-15T14:30:00+00:00')
      end

      it 'formats Time objects as ISO8601 strings' do
        time = Time.utc(2024, 3, 15, 14, 30, 0)
        result = subject.send(:format_date, time)
        expect(result).to eq('2024-03-15T14:30:00Z')
      end

      it 'formats valid ISO8601 string inputs' do
        date_string = '2024-03-15'
        result = subject.send(:format_date, date_string)
        expect(result).to eq('2024-03-15')
      end

      it 'returns nil for invalid date strings' do
        result = subject.send(:format_date, 'not-a-date')
        expect(result).to be_nil
      end

      it 'returns nil for nil input' do
        result = subject.send(:format_date, nil)
        expect(result).to be_nil
      end

      it 'returns nil for unsupported types' do
        result = subject.send(:format_date, 12_345)
        expect(result).to be_nil
      end
    end
  end

  describe '.permitted_params' do
    it 'returns base expense permitted parameters' do
      params = described_class.permitted_params
      expect(params).to eq(%i[purchase_date description cost_requested receipt])
    end

    it 'returns an array of symbols' do
      params = described_class.permitted_params
      expect(params).to be_an(Array)
      expect(params).to all(be_a(Symbol))
    end
  end

  describe '#to_service_params' do
    subject { described_class.new(valid_attributes.merge(claim_id: 'claim-uuid-123')) }

    it 'returns a hash with expense_type' do
      params = subject.to_service_params
      expect(params['expense_type']).to eq('other')
    end

    it 'includes formatted purchase_date' do
      params = subject.to_service_params
      expect(params['purchase_date']).to be_a(String)
      expect(params['purchase_date']).to match(/\d{4}-\d{2}-\d{2}/)
    end

    it 'includes description' do
      params = subject.to_service_params
      expect(params['description']).to eq('General expense')
    end

    it 'includes cost_requested' do
      params = subject.to_service_params
      expect(params['cost_requested']).to eq(100.00)
    end

    it 'includes claim_id when present' do
      params = subject.to_service_params
      expect(params['claim_id']).to eq('claim-uuid-123')
    end

    it 'excludes claim_id when nil' do
      subject.claim_id = nil
      params = subject.to_service_params
      expect(params).not_to have_key('claim_id')
    end

    it 'excludes claim_id when blank' do
      subject.claim_id = ''
      params = subject.to_service_params
      expect(params).not_to have_key('claim_id')
    end

    it 'handles nil purchase_date gracefully' do
      subject.purchase_date = nil
      params = subject.to_service_params
      expect(params['purchase_date']).to be_nil
    end

    context 'with receipt' do
      let(:receipt_data) do
        { file_name: 'receipt.pdf', content_type: 'application/pdf', file_data: 'contents',
          length: 120 }.with_indifferent_access
      end
      let(:expected_receipt_data) do
        { fileName: 'receipt.pdf', contentType: 'application/pdf', fileData: 'contents',
          length: 120 }.with_indifferent_access
      end

      it 'includes receipt when present' do
        subject.receipt = receipt_data
        params = subject.to_service_params
        expect(params['receipt']).to eq(expected_receipt_data)
      end

      it 'excludes receipt when nil' do
        subject.receipt = nil
        params = subject.to_service_params
        expect(params).not_to have_key('receipt')
      end

      it 'excludes receipt when blank' do
        subject.receipt = ''
        params = subject.to_service_params
        expect(params).not_to have_key('receipt')
      end
    end
  end
end
