# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::FlightExpense, type: :model do
  let(:valid_attributes) do
    {
      description: 'Flight to medical appointment',
      cost_requested: 350.00,
      purchase_date: Time.current,
      vendor: 'American Airlines',
      trip_type: 'RoundTrip',
      departure_location: 'San Francisco, CA',
      arrival_location: 'Denver, CO',
      departure_date: 1.day.from_now,
      arrival_date: 3.days.from_now
    }
  end

  describe 'inheritance' do
    it 'inherits from BaseExpense' do
      expect(described_class.superclass).to eq(TravelPay::BaseExpense)
    end
  end

  describe 'constants' do
    it 'uses TRIP_TYPES from Constants module' do
      expect(TravelPay::Constants::TRIP_TYPES.values).to eq(%w[OneWay RoundTrip Unspecified])
    end
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    context 'vendor validation' do
      it 'requires vendor to be present' do
        subject.vendor = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:vendor]).to include("can't be blank")
      end

      it 'requires vendor to be present when empty string' do
        subject.vendor = ''
        expect(subject).not_to be_valid
        expect(subject.errors[:vendor]).to include("can't be blank")
      end

      it 'enforces maximum length of 255 characters for vendor' do
        subject.vendor = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:vendor]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts valid vendor at maximum length' do
        subject.vendor = 'a' * 255
        expect(subject).to be_valid
      end

      it 'accepts valid vendor strings' do
        subject.vendor = 'Delta Airlines'
        expect(subject).to be_valid
      end
    end

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

        subject.trip_type = 'ROUND_TRIP'
        expect(subject).not_to be_valid
        expect(subject.errors[:trip_type]).to include('is not included in the list')
      end
    end

    context 'departure_location validation' do
      it 'requires departure_location to be present' do
        subject.departure_location = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:departure_location]).to include("can't be blank")
      end

      it 'enforces maximum length of 255 characters for departure_location' do
        subject.departure_location = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:departure_location]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts valid departure_location strings' do
        subject.departure_location = 'Los Angeles International Airport'
        expect(subject).to be_valid
      end
    end

    context 'arrival_location validation' do
      it 'requires arrival_location to be present' do
        subject.arrival_location = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:arrival_location]).to include("can't be blank")
      end

      it 'enforces maximum length of 255 characters for arrival_location' do
        subject.arrival_location = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:arrival_location]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts valid arrival_location strings' do
        subject.arrival_location = 'Denver International Airport'
        expect(subject).to be_valid
      end
    end

    context 'departure_date validation' do
      it 'requires departure_date to be present' do
        subject.departure_date = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:departure_date]).to include("can't be blank")
      end

      it 'accepts valid departure_date' do
        subject.departure_date = Time.current
        expect(subject).to be_valid
      end
    end

    context 'arrival_date validation' do
      it 'requires arrival_date to be present' do
        subject.arrival_date = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:arrival_date]).to include("can't be blank")
      end

      it 'accepts valid arrival_date' do
        subject.arrival_date = Time.current
        expect(subject).to be_valid
      end
    end
  end

  describe '#expense_type' do
    subject { described_class.new(valid_attributes) }

    it 'returns "airtravel" as the expense type' do
      expect(subject.expense_type).to eq('airtravel')
    end
  end

  describe '#to_h' do
    subject { described_class.new(valid_attributes.merge(claim_id: 'claim-789')) }

    it 'returns a hash representation including flight-specific attributes' do
      json = subject.to_h
      expect(json['vendor']).to eq('American Airlines')
      expect(json['trip_type']).to eq('RoundTrip')
      expect(json['departure_location']).to eq('San Francisco, CA')
      expect(json['arrival_location']).to eq('Denver, CO')
      expect(json['expense_type']).to eq('airtravel')
      expect(json['departure_date']).to be_present
      expect(json['arrival_date']).to be_present
    end
  end

  describe 'instantiation scenarios' do
    context 'creating a round trip flight expense' do
      let(:expense) do
        described_class.new(
          description: 'Round trip flight to VA medical center',
          cost_requested: 485.00,
          purchase_date: Date.current,
          vendor: 'United Airlines',
          trip_type: 'RoundTrip',
          departure_location: 'Chicago, IL',
          arrival_location: 'Phoenix, AZ',
          departure_date: 1.week.from_now,
          arrival_date: 2.weeks.from_now,
          claim_id: 'uuid-flight-123'
        )
      end

      it 'creates a valid round trip flight expense' do
        expect(expense).to be_valid
        expect(expense.vendor).to eq('United Airlines')
        expect(expense.trip_type).to eq('RoundTrip')
        expect(expense.departure_location).to eq('Chicago, IL')
        expect(expense.arrival_location).to eq('Phoenix, AZ')
        expect(expense.claim_id).to eq('uuid-flight-123')
        expect(expense.expense_type).to eq('airtravel')
      end
    end

    context 'creating a one way flight expense' do
      let(:expense) do
        described_class.new(
          description: 'One way flight for treatment',
          cost_requested: 275.00,
          purchase_date: 2.days.ago,
          vendor: 'Southwest Airlines',
          trip_type: 'OneWay',
          departure_location: 'Austin, TX',
          arrival_location: 'San Diego, CA',
          departure_date: 3.days.from_now,
          arrival_date: 3.days.from_now + 4.hours
        )
      end

      it 'creates a valid one way flight expense' do
        expect(expense).to be_valid
        expect(expense.trip_type).to eq('OneWay')
        expect(expense.vendor).to eq('Southwest Airlines')
      end
    end

    context 'creating an unspecified trip type flight expense' do
      let(:expense) do
        described_class.new(
          description: 'Emergency medical flight',
          cost_requested: 1200.00,
          purchase_date: 1.day.ago,
          vendor: 'Emergency Air Transport',
          trip_type: 'Unspecified',
          departure_location: 'Rural Hospital, MT',
          arrival_location: 'Mayo Clinic, MN',
          departure_date: Time.current,
          arrival_date: 2.hours.from_now
        )
      end

      it 'creates a valid unspecified trip type flight expense' do
        expect(expense).to be_valid
        expect(expense.trip_type).to eq('Unspecified')
        expect(expense.vendor).to eq('Emergency Air Transport')
      end
    end
  end

  describe 'edge cases and error conditions' do
    subject { described_class.new(valid_attributes) }

    it 'handles multiple FlightExpense validation errors gracefully' do
      subject.vendor = ''
      subject.trip_type = 'INVALID'
      subject.departure_location = nil
      subject.arrival_location = 'a' * 256

      expect(subject).not_to be_valid
      expect(subject.errors[:vendor]).to include("can't be blank")
      expect(subject.errors[:trip_type]).to include('is not included in the list')
      expect(subject.errors[:departure_location]).to include("can't be blank")
      expect(subject.errors[:arrival_location]).to include('is too long (maximum is 255 characters)')
    end

    it 'handles empty strings as invalid for required fields' do
      subject.vendor = ''
      subject.departure_location = ''
      subject.arrival_location = ''

      expect(subject).not_to be_valid
      expect(subject.errors[:vendor]).to include("can't be blank")
      expect(subject.errors[:departure_location]).to include("can't be blank")
      expect(subject.errors[:arrival_location]).to include("can't be blank")
    end
  end
end
