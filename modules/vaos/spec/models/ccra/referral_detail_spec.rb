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
          provider_npi: '1659458917'
        },
        treating_facility_info: {
          facility_name: 'VA Cardiology Clinic',
          facility_code: '528A7',
          phone: '505-555-1234',
          address: {
            address1: '123 Health Avenue',
            city: 'Albuquerque',
            state: 'NM',
            zip_code: '87107'
          }
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

      # Provider info
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.provider_npi).to eq('1659458917')

      # Referring facility info
      expect(subject.referring_facility_name).to eq('Bath VA Medical Center')
      expect(subject.referring_facility_phone).to eq('555-123-4567')
      expect(subject.referring_facility_code).to eq('528A6')
      expect(subject.referring_facility_address).to be_a(Hash)
      expect(subject.referring_facility_address[:street1]).to eq('801 VASSAR DR NE')
      expect(subject.referring_facility_address[:city]).to eq('ALBUQUERQUE')
      expect(subject.referring_facility_address[:state]).to eq('NM')
      expect(subject.referring_facility_address[:zip]).to eq('87106')

      # Treating facility info
      expect(subject.treating_facility_name).to eq('VA Cardiology Clinic')
      expect(subject.treating_facility_code).to eq('528A7')
      expect(subject.treating_facility_phone).to eq('505-555-1234')
      expect(subject.treating_facility_address).to be_a(Hash)
      expect(subject.treating_facility_address[:street1]).to eq('123 Health Avenue')
      expect(subject.treating_facility_address[:city]).to eq('Albuquerque')
      expect(subject.treating_facility_address[:state]).to eq('NM')
      expect(subject.treating_facility_address[:zip]).to eq('87107')
    end

    context 'with empty attributes' do
      subject { described_class.new({}) }

      include_examples 'has nil attributes'
    end

    context 'with nil attributes' do
      subject { described_class.new(nil) }

      include_examples 'has nil attributes'
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

    context 'with partial treating facility info' do
      it 'handles missing address information' do
        attributes = {
          treating_facility_info: {
            facility_name: 'VA Clinic',
            facility_code: '528A8',
            phone: '555-987-6543'
          }
        }
        detail = described_class.new(attributes)
        expect(detail.treating_facility_name).to eq('VA Clinic')
        expect(detail.treating_facility_code).to eq('528A8')
        expect(detail.treating_facility_phone).to eq('555-987-6543')
        expect(detail.treating_facility_address).to be_nil
      end
    end
  end

  describe '#json_serialization' do
    subject { described_class.new }

    let(:json_attributes) do
      {
        'expiration_date' => '2024-05-27',
        'category_of_care' => 'CARDIOLOGY',
        'treating_facility' => 'VA Medical Center',
        'referral_number' => 'VA0000005681',
        'referral_date' => '2024-07-24',
        'station_id' => '528A6',
        'has_appointments' => true,
        'provider_name' => 'Dr. Smith',
        'provider_npi' => '1659458917',
        'referring_facility_name' => 'Bath VA Medical Center',
        'referring_facility_phone' => '555-123-4567',
        'referring_facility_code' => '528A6',
        'referring_facility_address' => {
          'street1' => '801 VASSAR DR NE',
          'city' => 'ALBUQUERQUE',
          'state' => 'New Mexico',
          'zip' => '87106'
        },
        'treating_facility_name' => 'VA Cardiology Clinic',
        'treating_facility_code' => '528A7',
        'treating_facility_phone' => '505-555-1234',
        'treating_facility_address' => {
          'street1' => '123 Health Avenue',
          'city' => 'Albuquerque',
          'state' => 'New Mexico',
          'zip' => '87107'
        }
      }
    end

    let(:json_string) { json_attributes.to_json }

    before do
      # Directly set attributes on the instance using public methods
      subject.from_json(json_string)
    end

    it 'can deserialize from JSON' do
      expect(subject).to be_a(described_class)
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.category_of_care).to eq('CARDIOLOGY')
      expect(subject.treating_facility).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')
      expect(subject.referral_date).to eq('2024-07-24')
      expect(subject.station_id).to eq('528A6')
      expect(subject.has_appointments).to be(true)

      # Provider info
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.provider_npi).to eq('1659458917')
    end

    it 'symbolizes keys in the address hashes' do
      # Check referring facility address
      expect(subject.referring_facility_address).to be_a(Hash)
      expect(subject.referring_facility_address.keys.all? { |k| k.is_a?(Symbol) }).to be(true)
      expect(subject.referring_facility_address[:street1]).to eq('801 VASSAR DR NE')
      expect(subject.referring_facility_address[:city]).to eq('ALBUQUERQUE')
      expect(subject.referring_facility_address[:state]).to eq('New Mexico')
      expect(subject.referring_facility_address[:zip]).to eq('87106')

      # Check treating facility address
      expect(subject.treating_facility_address).to be_a(Hash)
      expect(subject.treating_facility_address.keys.all? { |k| k.is_a?(Symbol) }).to be(true)
      expect(subject.treating_facility_address[:street1]).to eq('123 Health Avenue')
      expect(subject.treating_facility_address[:city]).to eq('Albuquerque')
      expect(subject.treating_facility_address[:state]).to eq('New Mexico')
      expect(subject.treating_facility_address[:zip]).to eq('87107')
    end

    context 'with invalid JSON' do
      let(:invalid_json) { 'invalid json' }

      it 'handles invalid JSON gracefully' do
        model = described_class.new
        # This uses ActiveModel::Serializers::JSON's from_json method
        expect { model.from_json(invalid_json) }.to raise_error(JSON::ParserError)
      end
    end
  end
end
