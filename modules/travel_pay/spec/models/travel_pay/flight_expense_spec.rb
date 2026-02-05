# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::FlightExpense, type: :model do
  let(:valid_attributes) do
    {
      description: 'Flight to medical appointment',
      cost_requested: 350.00,
      purchase_date: Time.current,
      vendor_name: 'American Airlines',
      trip_type: 'RoundTrip',
      departed_from: 'San Francisco, CA',
      arrived_to: 'Denver, CO',
      departure_date: 1.day.from_now,
      return_date: 3.days.from_now
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

    context 'vendor_name validation' do
      it 'requires vendor_name to be present' do
        subject.vendor_name = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:vendor_name]).to include("can't be blank")
      end

      it 'requires vendor_name to be present when empty string' do
        subject.vendor_name = ''
        expect(subject).not_to be_valid
        expect(subject.errors[:vendor_name]).to include("can't be blank")
      end

      it 'enforces maximum length of 255 characters for vendor_name' do
        subject.vendor_name = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:vendor_name]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts valid vendor_name at maximum length' do
        subject.vendor_name = 'a' * 255
        expect(subject).to be_valid
      end

      it 'accepts valid vendor_name strings' do
        subject.vendor_name = 'Delta Airlines'
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

    context 'departed_from validation' do
      it 'requires departed_from to be present' do
        subject.departed_from = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:departed_from]).to include("can't be blank")
      end

      it 'enforces maximum length of 255 characters for departed_from' do
        subject.departed_from = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:departed_from]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts valid departed_from strings' do
        subject.departed_from = 'Los Angeles International Airport'
        expect(subject).to be_valid
      end
    end

    context 'arrived_to validation' do
      it 'requires arrived_to to be present' do
        subject.arrived_to = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:arrived_to]).to include("can't be blank")
      end

      it 'enforces maximum length of 255 characters for arrived_to' do
        subject.arrived_to = 'a' * 256
        expect(subject).not_to be_valid
        expect(subject.errors[:arrived_to]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts valid arrived_to strings' do
        subject.arrived_to = 'Denver International Airport'
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

    context 'return_date validation' do
      context 'when trip type is RoundTrip' do
        it 'requires return_date to be present' do
          subject.trip_type = 'RoundTrip'
          subject.return_date = nil
          expect(subject).not_to be_valid
          expect(subject.errors[:return_date]).to include("can't be blank")
        end

        it 'is invalid with empty string' do
          subject.trip_type = 'RoundTrip'
          subject.return_date = ''
          expect(subject).not_to be_valid
          expect(subject.errors[:return_date]).to include("can't be blank")
        end

        it 'accepts valid return_date' do
          subject.trip_type = 'RoundTrip'
          subject.return_date = 5.days.from_now
          expect(subject).to be_valid
        end
      end

      context 'when trip type is OneWay' do
        it 'allows return_date to be nil' do
          subject.trip_type = 'OneWay'
          subject.return_date = nil
          expect(subject).to be_valid
          expect(subject.errors[:return_date]).to be_empty
        end

        it 'allows return_date to be empty string' do
          subject.trip_type = 'OneWay'
          subject.return_date = ''
          expect(subject).to be_valid
        end

        it 'accepts return_date if provided' do
          subject.trip_type = 'OneWay'
          subject.return_date = 5.days.from_now
          expect(subject).to be_valid
        end
      end

      context 'when trip type is Unspecified' do
        it 'allows return_date to be nil' do
          subject.trip_type = 'Unspecified'
          subject.return_date = nil
          expect(subject).to be_valid
          expect(subject.errors[:return_date]).to be_empty
        end
      end
    end

    context 'custom validations' do
      describe 'departure and arrival locations must be different' do
        context 'when trip type is RoundTrip' do
          it 'is invalid when departure and arrival locations are identical' do
            subject.trip_type = 'RoundTrip'
            subject.departed_from = 'Denver, CO'
            subject.arrived_to = 'Denver, CO'
            expect(subject).not_to be_valid
            expect(subject.errors[:arrived_to]).to include('must be different from departure location')
          end

          it 'is invalid when departure and arrival locations are identical (case insensitive)' do
            subject.trip_type = 'RoundTrip'
            subject.departed_from = 'Denver, CO'
            subject.arrived_to = 'DENVER, CO'
            expect(subject).not_to be_valid
            expect(subject.errors[:arrived_to]).to include('must be different from departure location')
          end

          it 'is invalid when departure and arrival locations are identical (with extra whitespace)' do
            subject.trip_type = 'RoundTrip'
            subject.departed_from = ' Denver, CO '
            subject.arrived_to = 'Denver, CO'
            expect(subject).not_to be_valid
            expect(subject.errors[:arrived_to]).to include('must be different from departure location')
          end

          it 'is valid when departure and arrival locations are different' do
            subject.trip_type = 'RoundTrip'
            subject.departed_from = 'San Francisco, CA'
            subject.arrived_to = 'Denver, CO'
            expect(subject).to be_valid
          end

          it 'skips validation when either location is missing' do
            subject.trip_type = 'RoundTrip'
            subject.departed_from = nil
            subject.arrived_to = 'Denver, CO'
            # Should not add location difference error (presence validation will catch the nil)
            subject.valid?
            expect(subject.errors[:arrived_to]).not_to include('must be different from departure location')
          end
        end

        context 'when trip type is OneWay' do
          it 'does not validate location difference' do
            subject.trip_type = 'OneWay'
            subject.departed_from = 'Denver, CO'
            subject.arrived_to = 'Denver, CO'
            subject.return_date = nil
            expect(subject).to be_valid
          end
        end

        context 'when trip type is Unspecified' do
          it 'does not validate location difference' do
            subject.trip_type = 'Unspecified'
            subject.departed_from = 'Denver, CO'
            subject.arrived_to = 'Denver, CO'
            subject.return_date = nil
            expect(subject).to be_valid
          end
        end
      end

      describe 'departure date must be before return date' do
        context 'when trip type is RoundTrip' do
          it 'is invalid when departure date is after return date' do
            subject.trip_type = 'RoundTrip'
            subject.departure_date = 3.days.from_now
            subject.return_date = 1.day.from_now
            expect(subject).not_to be_valid
            expect(subject.errors[:return_date]).to include('must be after departure date')
          end

          it 'is valid when departure date equals return date' do
            subject.trip_type = 'RoundTrip'
            same_time = 2.days.from_now
            subject.departure_date = same_time
            subject.return_date = same_time
            expect(subject).to be_valid
          end

          it 'is valid when departure date is before return date' do
            subject.trip_type = 'RoundTrip'
            subject.departure_date = 1.day.from_now
            subject.return_date = 3.days.from_now
            expect(subject).to be_valid
          end

          it 'is valid when departure and return are on same day with different times' do
            subject.trip_type = 'RoundTrip'
            base_date = 2.days.from_now.beginning_of_day
            subject.departure_date = base_date + 8.hours # 8:00 AM
            subject.return_date = base_date + 14.hours # 2:00 PM
            expect(subject).to be_valid
          end

          it 'is valid when departure and return are on same day but times are reversed' do
            subject.trip_type = 'RoundTrip'
            base_date = 2.days.from_now.beginning_of_day
            subject.departure_date = base_date + 14.hours # 2:00 PM
            subject.return_date = base_date + 8.hours # 8:00 AM
            # Should still be valid because we only compare dates, not times
            expect(subject).to be_valid
          end

          it 'skips validation when either date is missing' do
            subject.trip_type = 'RoundTrip'
            subject.departure_date = nil
            subject.return_date = 3.days.from_now
            # Should not add date comparison error (presence validation will catch the nil)
            subject.valid?
            expect(subject.errors[:return_date]).not_to include('must be after departure date')
          end
        end

        context 'when trip type is OneWay' do
          it 'does not validate date comparison' do
            subject.trip_type = 'OneWay'
            subject.departure_date = 3.days.from_now
            subject.return_date = 1.day.from_now
            expect(subject).to be_valid
          end

          it 'allows same dates without error' do
            subject.trip_type = 'OneWay'
            same_time = 2.days.from_now
            subject.departure_date = same_time
            subject.return_date = same_time
            expect(subject).to be_valid
          end
        end

        context 'when trip type is Unspecified' do
          it 'does not validate date comparison' do
            subject.trip_type = 'Unspecified'
            subject.departure_date = 3.days.from_now
            subject.return_date = 1.day.from_now
            expect(subject).to be_valid
          end
        end
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
      expect(json['vendor_name']).to eq('American Airlines')
      expect(json['trip_type']).to eq('RoundTrip')
      expect(json['departed_from']).to eq('San Francisco, CA')
      expect(json['arrived_to']).to eq('Denver, CO')
      expect(json['expense_type']).to eq('airtravel')
      expect(json['departure_date']).to be_present
      expect(json['return_date']).to be_present
    end
  end

  describe 'instantiation scenarios' do
    context 'creating a round trip flight expense' do
      let(:expense) do
        described_class.new(
          description: 'Round trip flight to VA medical center',
          cost_requested: 485.00,
          purchase_date: Date.current,
          vendor_name: 'United Airlines',
          trip_type: 'RoundTrip',
          departed_from: 'Chicago, IL',
          arrived_to: 'Phoenix, AZ',
          departure_date: 1.week.from_now,
          return_date: 2.weeks.from_now,
          claim_id: 'uuid-flight-123'
        )
      end

      it 'creates a valid round trip flight expense' do
        expect(expense).to be_valid
        expect(expense.vendor_name).to eq('United Airlines')
        expect(expense.trip_type).to eq('RoundTrip')
        expect(expense.departed_from).to eq('Chicago, IL')
        expect(expense.arrived_to).to eq('Phoenix, AZ')
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
          vendor_name: 'Southwest Airlines',
          trip_type: 'OneWay',
          departed_from: 'Austin, TX',
          arrived_to: 'San Diego, CA',
          departure_date: 3.days.from_now
        )
      end

      it 'creates a valid one way flight expense without return_date' do
        expect(expense).to be_valid
        expect(expense.trip_type).to eq('OneWay')
        expect(expense.vendor_name).to eq('Southwest Airlines')
        expect(expense.return_date).to be_nil
      end
    end

    context 'creating an unspecified trip type flight expense' do
      let(:expense) do
        described_class.new(
          description: 'Emergency medical flight',
          cost_requested: 1200.00,
          purchase_date: 1.day.ago,
          vendor_name: 'Emergency Air Transport',
          trip_type: 'Unspecified',
          departed_from: 'Rural Hospital, MT',
          arrived_to: 'Mayo Clinic, MN',
          departure_date: Time.current
        )
      end

      it 'creates a valid unspecified trip type flight expense without return_date' do
        expect(expense).to be_valid
        expect(expense.trip_type).to eq('Unspecified')
        expect(expense.vendor_name).to eq('Emergency Air Transport')
        expect(expense.return_date).to be_nil
      end
    end
  end

  describe 'edge cases and error conditions' do
    subject { described_class.new(valid_attributes) }

    it 'handles multiple FlightExpense validation errors gracefully' do
      subject.vendor_name = ''
      subject.trip_type = 'INVALID'
      subject.departed_from = nil
      subject.arrived_to = 'a' * 256

      expect(subject).not_to be_valid
      expect(subject.errors[:vendor_name]).to include("can't be blank")
      expect(subject.errors[:trip_type]).to include('is not included in the list')
      expect(subject.errors[:departed_from]).to include("can't be blank")
      expect(subject.errors[:arrived_to]).to include('is too long (maximum is 255 characters)')
    end

    it 'handles empty strings as invalid for required fields' do
      subject.vendor_name = ''
      subject.departed_from = ''
      subject.arrived_to = ''

      expect(subject).not_to be_valid
      expect(subject.errors[:vendor_name]).to include("can't be blank")
      expect(subject.errors[:departed_from]).to include("can't be blank")
      expect(subject.errors[:arrived_to]).to include("can't be blank")
    end

    it 'handles multiple custom validation errors for round trips' do
      subject.trip_type = 'RoundTrip'
      subject.departed_from = 'Same City'
      subject.arrived_to = 'Same City'
      subject.departure_date = 3.days.from_now
      subject.return_date = 1.day.from_now

      expect(subject).not_to be_valid
      expect(subject.errors[:arrived_to]).to include('must be different from departure location')
      expect(subject.errors[:return_date]).to include('must be after departure date')
    end

    it 'combines built-in and custom validation errors for round trips' do
      subject.trip_type = 'RoundTrip'
      subject.vendor_name = ''
      subject.departed_from = 'Same Location'
      subject.arrived_to = 'Same Location'
      subject.departure_date = 2.days.from_now
      subject.return_date = 1.day.from_now

      expect(subject).not_to be_valid
      expect(subject.errors[:vendor_name]).to include("can't be blank")
      expect(subject.errors[:arrived_to]).to include('must be different from departure location')
      expect(subject.errors[:return_date]).to include('must be after departure date')
    end
  end

  describe '.permitted_params' do
    it 'extends base expense permitted parameters with flight-specific fields' do
      params = described_class.permitted_params
      expect(params).to include(:vendor_name, :trip_type, :departed_from, :arrived_to, :departure_date,
                                :return_date)
    end
  end

  describe '#to_service_params' do
    subject do
      described_class.new(
        purchase_date: Date.new(2024, 3, 15),
        description: 'Flight to medical appointment',
        cost_requested: 350.00,
        vendor_name: 'Delta Airlines',
        trip_type: 'RoundTrip',
        departed_from: 'Atlanta, GA',
        arrived_to: 'Boston, MA',
        departure_date: DateTime.new(2024, 3, 15, 10, 0, 0),
        return_date: DateTime.new(2024, 3, 15, 14, 30, 0),
        claim_id: 'claim-uuid-flight'
      )
    end

    it 'includes flight-specific fields' do
      params = subject.to_service_params
      expect(params['vendor_name']).to eq('Delta Airlines')
      expect(params['trip_type']).to eq('RoundTrip')
      expect(params['departed_from']).to eq('Atlanta, GA')
      expect(params['arrived_to']).to eq('Boston, MA')
    end

    it 'formats datetime fields as ISO8601 strings' do
      params = subject.to_service_params
      expect(params['departure_date']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      expect(params['return_date']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end
end
