# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralDetail do
  # Shared example for testing nil attributes
  shared_examples 'has nil attributes' do
    it 'sets all attributes to nil' do
      # Use reflection to iterate through the object's instance variables
      instance_variables = subject.instance_variables.reject { |v| v == :@uuid }
      instance_variables.each do |var|
        value = subject.instance_variable_get(var)
        expect(value).to be_nil, "Expected #{var} to be nil, but got #{value.inspect}"
      end
    end
  end

  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        referral_expiration_date: '2024-05-27',
        category_of_care: 'CARDIOLOGY',
        treating_facility: 'VA Medical Center',
        referral_number: 'VA0000005681',
        referral_date: '2024-07-24',
        station_id: '528A6',
        appointments: [{ appointment_date: '2024-08-15' }],
        referring_facility_info: {
          facility_name: 'Bath VA Medical Center',
          phone: '555-123-4567',
          facility_code: '528A6',
          address: {
            address1: '801 VASSAR DR NE',
            city: 'ALBUQUERQUE',
            state: 'NM',
            zip_code: '87106'
          }
        },
        treating_provider_info: {
          provider_name: 'Dr. Smith',
          provider_npi: '1659458917',
          telephone: '505-248-4062'
        },
        treating_facility_info: {
          phone: '505-555-1234'
        }
      }
    end

    it 'sets all attributes correctly' do
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.category_of_care).to eq('CARDIOLOGY')
      expect(subject.treating_facility).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')
      expect(subject.referral_date).to eq('2024-07-24')
      expect(subject.station_id).to eq('528A6')
      expect(subject.uuid).to be_nil
      expect(subject.has_appointments).to be(true)

      # Phone number should come from treating facility
      expect(subject.phone_number).to eq('505-555-1234')

      # Provider info
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.provider_npi).to eq('1659458917')
      expect(subject.provider_telephone).to eq('505-248-4062')

      # Referring facility info
      expect(subject.referring_facility_name).to eq('Bath VA Medical Center')
      expect(subject.referring_facility_phone).to eq('555-123-4567')
      expect(subject.referring_facility_code).to eq('528A6')
      expect(subject.referring_facility_address).to be_a(Hash)
      expect(subject.referring_facility_address[:street1]).to eq('801 VASSAR DR NE')
      expect(subject.referring_facility_address[:city]).to eq('ALBUQUERQUE')
      expect(subject.referring_facility_address[:state]).to eq('NM')
      expect(subject.referring_facility_address[:zip]).to eq('87106')
    end

    context 'with empty attributes' do
      subject { described_class.new({}) }

      include_examples 'has nil attributes'
    end

    context 'with nil attributes' do
      subject { described_class.new(nil) }

      include_examples 'has nil attributes'
    end

    context 'when phone number comes from provider info' do
      subject { described_class.new(provider_phone_attributes) }

      let(:provider_phone_attributes) do
        {
          treating_facility_info: {},
          treating_provider_info: {
            telephone: '123-456-7890'
          }
        }
      end

      it 'uses provider telephone as phone_number' do
        expect(subject.phone_number).to eq('123-456-7890')
      end
    end

    context 'with appointments array' do
      it 'sets has_appointments to true when appointments are present' do
        attributes = { appointments: [{ appointment_date: '2024-08-15' }] }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be(true)
      end

      it 'sets has_appointments to false when appointments is empty array' do
        attributes = { appointments: [] }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be(false)
      end

      it 'sets has_appointments to false when appointments is nil' do
        attributes = { appointments: nil }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be(false)
      end
    end
  end
end
