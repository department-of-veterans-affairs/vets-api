# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::BaseExpense, type: :model do
  let(:valid_attributes) do
    {
      description: 'Hotel accommodation',
      cost_requested: 150.00,
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

    it 'includes ActiveModel::Serialization' do
      expect(described_class.ancestors).to include(ActiveModel::Serialization)
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
      it 'requires description to be present' do
        subject.description = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:description]).to include("can't be blank")
      end

      it 'requires description to be 255 characters or less' do
        subject.description = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:description]).to include('is too long (maximum is 255 characters)')
      end

      it 'allows description of exactly 255 characters' do
        subject.description = 'a' * 255
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
  end

  describe '#as_json' do
    subject { described_class.new(valid_attributes.merge(claim_id: 'claim-123')) }

    it 'returns a hash representation including core attributes' do
      json = subject.as_json
      expect(json['description']).to eq('Hotel accommodation')
      expect(json['cost_requested']).to eq(150.00)
      expect(json['claim_id']).to eq('claim-123')
    end

    it 'includes has_receipt flag when receipt is nil' do
      json = subject.as_json
      expect(json['has_receipt']).to be false
    end

    it 'includes has_receipt flag when receipt is present' do
      subject.receipt = double('Receipt')
      json = subject.as_json
      expect(json['has_receipt']).to be true
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

        def self.name
          'CustomExpense'
        end
      end
    end

    it 'allows subclasses to override expense_type' do
      custom_expense = custom_expense_class.new(valid_attributes)
      expect(custom_expense.expense_type).to eq('custom')
    end

    it 'inherits all validations' do
      custom_expense = custom_expense_class.new
      custom_expense.valid?
      expect(custom_expense.errors[:description]).to include("can't be blank")
      expect(custom_expense.errors[:cost_requested]).to include("can't be blank")
      expect(custom_expense.errors[:purchase_date]).to include("can't be blank")
    end
  end

  describe 'instantiation scenarios' do
    context 'creating a basic expense' do
      let(:expense) do
        described_class.new(
          description: 'Taxi fare',
          cost_requested: 45.75,
          purchase_date: Date.current
        )
      end

      it 'creates a valid expense' do
        expect(expense).to be_valid
        expect(expense.description).to eq('Taxi fare')
        expect(expense.cost_requested).to eq(45.75)
        expect(expense.expense_type).to eq('other')
      end
    end

    context 'creating an expense with claim association' do
      let(:expense) do
        described_class.new(
          description: 'Meal expense',
          cost_requested: 25.50,
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
      let(:mock_receipt) { double('Receipt', id: 'receipt-123') }
      let(:expense) do
        described_class.new(
          description: 'Gas expense',
          cost_requested: 75.00,
          purchase_date: Date.current,
          receipt: mock_receipt
        )
      end

      it 'creates a valid expense with receipt' do
        expect(expense).to be_valid
        expect(expense.receipt).to eq(mock_receipt)
        expect(expense.as_json['has_receipt']).to be true
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
  end
end
