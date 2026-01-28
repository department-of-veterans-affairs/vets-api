# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::CommonCarrierExpense, type: :model do
  let(:valid_attributes) do
    {
      description: 'Taxi to medical appointment',
      cost_requested: 25.00,
      purchase_date: Time.current,
      reason_not_using_pov: 'Medically Indicated',
      carrier_type: 'Taxi'
    }
  end

  describe 'inheritance' do
    it 'inherits from BaseExpense' do
      expect(described_class.superclass).to eq(TravelPay::BaseExpense)
    end
  end

  describe 'constants' do
    it 'uses COMMON_CARRIER_EXPLANATIONS from Constants module' do
      expect(TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.values).to eq(['Privately Owned Vehicle Not Available',
                                                                              'Medically Indicated',
                                                                              'Other',
                                                                              'Unspecified'])
    end

    it 'uses COMMON_CARRIER_TYPES from Constants module' do
      expect(TravelPay::Constants::COMMON_CARRIER_TYPES.values).to eq(%w[Bus Subway Taxi Train Other])
    end
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    context 'reason_not_using_pov validation' do
      it 'requires reason_not_using_pov to be present' do
        subject.reason_not_using_pov = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:reason_not_using_pov]).to include("can't be blank")
      end

      it 'requires reason_not_using_pov to be in valid options' do
        subject.reason_not_using_pov = 'INVALID_EXPLANATION'
        expect(subject).not_to be_valid
        expect(subject.errors[:reason_not_using_pov]).to include('is not included in the list')
      end

      it 'accepts valid reason_not_using_pov values' do
        subject.reason_not_using_pov = 'Privately Owned Vehicle Not Available'
        expect(subject).to be_valid

        subject.reason_not_using_pov = 'Medically Indicated'
        expect(subject).to be_valid

        subject.reason_not_using_pov = 'Other'
        expect(subject).to be_valid

        subject.reason_not_using_pov = 'Unspecified'
        expect(subject).to be_valid
      end

      it 'normalizes snake_case values into valid explanations' do
        subject.reason_not_using_pov = 'privately_owned_vehicle_not_available'
        expect(subject).to be_valid
        expect(subject.reason_not_using_pov)
          .to eq('Privately Owned Vehicle Not Available')

        subject.reason_not_using_pov = 'medically_indicated'
        expect(subject).to be_valid
        expect(subject.reason_not_using_pov)
          .to eq('Medically Indicated')
      end

      it 'normalizes all snake_case keys into proper explanations' do
        TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.each_key do |key|
          snake_case = key.to_s
          subject.reason_not_using_pov = snake_case
          expect(subject).to be_valid, "Expected #{snake_case} to be valid"
          expect(subject.reason_not_using_pov).to eq(TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS[key])
        end
      end
    end

    context 'carrier_type validation' do
      it 'requires carrier_type to be present' do
        subject.carrier_type = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:carrier_type]).to include("can't be blank")
      end

      it 'requires carrier_type to be in valid options' do
        subject.carrier_type = 'INVALID_TYPE'
        expect(subject).not_to be_valid
        expect(subject.errors[:carrier_type]).to include('is not included in the list')
      end

      it 'accepts valid carrier_type values' do
        subject.carrier_type = 'Bus'
        expect(subject).to be_valid

        subject.carrier_type = 'Subway'
        expect(subject).to be_valid

        subject.carrier_type = 'Taxi'
        expect(subject).to be_valid

        subject.carrier_type = 'Train'
        expect(subject).to be_valid

        subject.carrier_type = 'Other'
        expect(subject).to be_valid
      end

      it 'rejects invalid casing' do
        subject.carrier_type = 'bus'
        expect(subject).not_to be_valid
        expect(subject.errors[:carrier_type]).to include('is not included in the list')

        subject.carrier_type = 'BUS'
        expect(subject).not_to be_valid
        expect(subject.errors[:carrier_type]).to include('is not included in the list')
      end
    end
  end

  describe '#expense_type' do
    subject { described_class.new(valid_attributes) }

    it 'returns "commoncarrier" as the expense type' do
      expect(subject.expense_type).to eq('commoncarrier')
    end
  end

  describe '#to_h' do
    subject { described_class.new(valid_attributes.merge(claim_id: 'claim-123')) }

    it 'returns a hash representation including common carrier-specific attributes' do
      json = subject.to_h
      expect(json['reason_not_using_pov']).to eq('Medically Indicated')
      expect(json['carrier_type']).to eq('Taxi')
      expect(json['expense_type']).to eq('commoncarrier')
    end
  end

  describe 'instantiation scenarios' do
    context 'creating a common carrier expense with all attributes' do
      let(:expense) do
        described_class.new(
          description: 'Bus fare to VA medical center',
          cost_requested: 15.50,
          purchase_date: Date.current,
          reason_not_using_pov: 'Privately Owned Vehicle Not Available',
          carrier_type: 'Bus',
          claim_id: 'uuid-456'
        )
      end

      it 'creates a valid common carrier expense' do
        expect(expense).to be_valid
        expect(expense.reason_not_using_pov).to eq('Privately Owned Vehicle Not Available')
        expect(expense.carrier_type).to eq('Bus')
        expect(expense.claim_id).to eq('uuid-456')
        expect(expense.expense_type).to eq('commoncarrier')
      end
    end

    context 'creating a subway expense with medical indication' do
      let(:expense) do
        described_class.new(
          description: 'Subway to appointment',
          cost_requested: 8.75,
          purchase_date: 2.days.ago,
          reason_not_using_pov: 'Medically Indicated',
          carrier_type: 'Subway'
        )
      end

      it 'creates a valid subway expense' do
        expect(expense).to be_valid
        expect(expense.carrier_type).to eq('Subway')
        expect(expense.reason_not_using_pov).to eq('Medically Indicated')
      end
    end

    context 'creating a train expense with other explanation' do
      let(:expense) do
        described_class.new(
          description: 'Train to regional medical facility',
          cost_requested: 45.00,
          purchase_date: 1.week.ago,
          reason_not_using_pov: 'Other',
          carrier_type: 'Train'
        )
      end

      it 'creates a valid train expense' do
        expect(expense).to be_valid
        expect(expense.carrier_type).to eq('Train')
        expect(expense.reason_not_using_pov).to eq('Other')
      end
    end
  end

  describe 'edge cases and error conditions' do
    subject { described_class.new(valid_attributes) }

    it 'handles multiple CommonCarrierExpense validation errors gracefully' do
      subject.reason_not_using_pov = 'INVALID'
      subject.carrier_type = 'invalid_type'

      expect(subject).not_to be_valid
      expect(subject.errors[:reason_not_using_pov]).to include('is not included in the list')
      expect(subject.errors[:carrier_type]).to include('is not included in the list')
    end

    it 'handles empty strings as invalid for CommonCarrierExpense fields' do
      subject.reason_not_using_pov = ''
      subject.carrier_type = ''

      expect(subject).not_to be_valid
      expect(subject.errors[:reason_not_using_pov]).to include("can't be blank")
      expect(subject.errors[:carrier_type]).to include("can't be blank")
    end
  end

  describe '.permitted_params' do
    it 'extends base expense permitted parameters with common carrier-specific fields' do
      params = described_class.permitted_params
      expect(params).to include(:reason_not_using_pov, :carrier_type)
    end
  end

  describe '#to_service_params' do
    subject do
      described_class.new(
        purchase_date: Date.new(2024, 3, 15),
        description: 'Taxi to hospital',
        cost_requested: 45.00,
        reason_not_using_pov: 'Medically Indicated',
        carrier_type: 'Taxi',
        claim_id: 'claim-uuid-carrier'
      )
    end

    it 'includes common carrier-specific fields' do
      params = subject.to_service_params
      expect(params['reason_not_using_pov']).to eq('Medically Indicated')
      expect(params['carrier_type']).to eq('Taxi')
    end
  end
end
