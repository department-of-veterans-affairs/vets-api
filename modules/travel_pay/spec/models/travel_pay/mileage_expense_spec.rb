# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::MileageExpense, type: :model do
  let(:valid_attributes) do
    {
      description: 'Travel to appointment',
      cost_requested: 50.00,
      purchase_date: Time.current,
      trip_type: 'OneWay'
    }
  end

  describe 'inheritance' do
    it 'inherits from BaseExpense' do
      expect(described_class.superclass).to eq(TravelPay::BaseExpense)
    end
  end

  describe 'constants' do
    it 'defines VALID_TRIP_TYPES constant' do
      expect(described_class::VALID_TRIP_TYPES).to eq(%w[OneWay RoundTrip Unspecified])
    end
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    context 'trip_type validation' do
      it 'requires trip_type to be present' do
        subject.trip_type = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:trip_type]).to include("can't be blank")
      end

      it 'requires trip_type to be in valid options' do
        subject.trip_type = 'INVALID_TYPE'
        expect(subject).not_to be_valid
        expect(subject.errors[:trip_type]).to include('is not included in the list')
      end

      it 'accepts valid trip_type values' do
        subject.trip_type = 'OneWay'
        expect(subject).to be_valid

        subject.trip_type = 'RoundTrip'
        expect(subject).to be_valid

        subject.trip_type = 'Unspecified'
        expect(subject).to be_valid
      end

      it 'rejects invalid casing' do
        subject.trip_type = 'one_way'
        expect(subject).not_to be_valid
        expect(subject.errors[:trip_type]).to include('is not included in the list')

        subject.trip_type = 'ONE_WAY'
        expect(subject).not_to be_valid
        expect(subject.errors[:trip_type]).to include('is not included in the list')
      end
    end

    context 'requested_mileage validation' do
      it 'is valid when requested_mileage is nil (optional)' do
        subject.requested_mileage = nil
        expect(subject).to be_valid
      end

      it 'requires requested_mileage to be greater than 0.0 when present' do
        subject.requested_mileage = 0.0
        expect(subject).not_to be_valid
        expect(subject.errors[:requested_mileage]).to include('must be greater than 0.0')

        subject.requested_mileage = -5.5
        expect(subject).not_to be_valid
        expect(subject.errors[:requested_mileage]).to include('must be greater than 0.0')
      end

      it 'accepts positive requested_mileage values' do
        subject.requested_mileage = 25.5
        expect(subject).to be_valid
      end
    end
  end

  describe '#expense_type' do
    subject { described_class.new(valid_attributes) }

    it 'returns "mileage" as the expense type' do
      expect(subject.expense_type).to eq('mileage')
    end
  end

  describe '#to_h' do
    subject { described_class.new(valid_attributes.merge(claim_id: 'claim-123', requested_mileage: 42.5)) }

    it 'returns a hash representation including mileage-specific attributes' do
      json = subject.to_h
      expect(json['trip_type']).to eq('OneWay')
      expect(json['requested_mileage']).to eq(42.5)
      expect(json['expense_type']).to eq('mileage')
    end

    it 'includes inherited BaseExpense attributes' do
      json = subject.to_h
      expect(json['description']).to eq('Travel to appointment')
      expect(json['cost_requested']).to eq(50.00)
      expect(json['claim_id']).to eq('claim-123')
      expect(json['has_receipt']).to be false
    end

    it 'handles nil requested_mileage gracefully' do
      subject.requested_mileage = nil
      json = subject.to_h
      expect(json['requested_mileage']).to be_nil
      expect(json['trip_type']).to eq('OneWay')
    end
  end

  describe 'instantiation scenarios' do
    context 'creating a mileage expense with all attributes' do
      let(:expense) do
        described_class.new(
          description: 'Travel for medical appointment',
          cost_requested: 25.00,
          purchase_date: Date.current,
          trip_type: 'RoundTrip',
          requested_mileage: 35.2,
          claim_id: 'uuid-123'
        )
      end

      it 'creates a valid mileage expense' do
        expect(expense).to be_valid
        expect(expense.trip_type).to eq('RoundTrip')
        expect(expense.requested_mileage).to eq(35.2)
        expect(expense.claim_id).to eq('uuid-123')
        expect(expense.expense_type).to eq('mileage')
      end
    end
  end
end
