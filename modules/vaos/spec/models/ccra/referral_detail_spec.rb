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
        'referralExpirationDate' => '2024-05-27',
        'categoryOfCare' => 'CARDIOLOGY',
        'treatingFacility' => 'VA Medical Center',
        'referralNumber' => 'VA0000005681',
        'referralDate' => '2024-07-24',
        'stationId' => '528A6',
        'appointments' => [{ 'appointmentDate' => '2024-08-15' }],
        'referringFacilityInfo' => {
          'facilityName' => 'Bath VA Medical Center',
          'phone' => '555-123-4567',
          'facilityCode' => '528A6',
          'address' => {
            'address1' => '801 VASSAR DR NE',
            'city' => 'ALBUQUERQUE',
            'state' => 'NM',
            'zipCode' => '87106'
          }
        },
        'treatingProviderInfo' => {
          'providerName' => 'Dr. Smith',
          'providerNpi' => '1659458917',
          'telephone' => '505-248-4062'
        },
        'treatingFacilityInfo' => {
          'phone' => '505-555-1234'
        }
      }
    end

    it 'sets all attributes correctly' do
      expect(subject.expirationDate).to eq('2024-05-27')
      expect(subject.categoryOfCare).to eq('CARDIOLOGY')
      expect(subject.treatingFacility).to eq('VA Medical Center')
      expect(subject.referralNumber).to eq('VA0000005681')
      expect(subject.referralDate).to eq('2024-07-24')
      expect(subject.stationId).to eq('528A6')
      expect(subject.uuid).to be_nil
      expect(subject.hasAppointments).to be(true)

      # Phone number should come from treating facility
      expect(subject.phoneNumber).to eq('505-555-1234')

      # Provider info
      expect(subject.providerName).to eq('Dr. Smith')
      expect(subject.providerNpi).to eq('1659458917')
      expect(subject.providerTelephone).to eq('505-248-4062')

      # Referring facility info
      expect(subject.referringFacilityName).to eq('Bath VA Medical Center')
      expect(subject.referringFacilityPhone).to eq('555-123-4567')
      expect(subject.referringFacilityCode).to eq('528A6')
      expect(subject.referringFacilityAddress).to be_a(Hash)
      expect(subject.referringFacilityAddress[:street1]).to eq('801 VASSAR DR NE')
      expect(subject.referringFacilityAddress[:city]).to eq('ALBUQUERQUE')
      expect(subject.referringFacilityAddress[:state]).to eq('NM')
      expect(subject.referringFacilityAddress[:zip]).to eq('87106')
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
          'treatingFacilityInfo' => {},
          'treatingProviderInfo' => {
            'telephone' => '123-456-7890'
          }
        }
      end

      it 'uses provider telephone as phone_number' do
        expect(subject.phoneNumber).to eq('123-456-7890')
      end
    end

    context 'with appointments array' do
      it 'sets hasAppointments to true when appointments are present' do
        attributes = { 'appointments' => [{ 'appointmentDate' => '2024-08-15' }] }
        detail = described_class.new(attributes)
        expect(detail.hasAppointments).to be(true)
      end

      it 'sets hasAppointments to false when appointments is empty array' do
        attributes = { 'appointments' => [] }
        detail = described_class.new(attributes)
        expect(detail.hasAppointments).to be(false)
      end

      it 'sets hasAppointments to false when appointments is nil' do
        attributes = { 'appointments' => nil }
        detail = described_class.new(attributes)
        expect(detail.hasAppointments).to be(false)
      end
    end
  end
end
