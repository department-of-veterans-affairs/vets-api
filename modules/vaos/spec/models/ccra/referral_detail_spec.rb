# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralDetail do
  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        'Referral' => {
          'ReferralExpirationDate' => '2024-05-27',
          'CategoryOfCare' => 'CARDIOLOGY',
          'TreatingFacility' => 'VA Medical Center',
          'ReferralNumber' => 'VA0000005681',
          'referralDate' => '2024-07-24',
          'stationId' => '528A6',
          'APPTYesNo1' => 'Y',
          'ReferringFacilityInfo' => {
            'FacilityName' => 'Bath VA Medical Center',
            'Phone' => '555-123-4567',
            'FacilityCode' => '528A6',
            'Address' => {
              'Address1' => '801 VASSAR DR NE',
              'City' => 'ALBUQUERQUE',
              'State' => 'NM',
              'ZipCode' => '87106'
            }
          },
          'TreatingProviderInfo' => {
            'ProviderName' => 'Dr. Smith',
            'ProviderNPI' => '1659458917',
            'Telephone' => '505-248-4062'
          },
          'TreatingFacilityInfo' => {
            'Phone' => '505-555-1234'
          }
        }
      }
    end

    it 'sets all attributes correctly' do
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.referral_expiration_date).to eq('2024-05-27')
      expect(subject.type_of_care).to eq('CARDIOLOGY')
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

    context 'with missing Referral key' do
      subject { described_class.new({}) }

      it 'sets all attributes to nil' do
        expect(subject.expiration_date).to be_nil
        expect(subject.referral_expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.treating_facility).to be_nil
        expect(subject.referral_number).to be_nil
        expect(subject.referral_date).to be_nil
        expect(subject.station_id).to be_nil
        expect(subject.uuid).to be_nil
        expect(subject.has_appointments).to be_nil
        expect(subject.phone_number).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.provider_npi).to be_nil
        expect(subject.provider_telephone).to be_nil
        expect(subject.referring_facility_name).to be_nil
        expect(subject.referring_facility_phone).to be_nil
        expect(subject.referring_facility_code).to be_nil
        expect(subject.referring_facility_address).to be_nil
      end
    end

    context 'with nil Referral value' do
      subject { described_class.new({ 'Referral' => nil }) }

      it 'sets all attributes to nil' do
        expect(subject.expiration_date).to be_nil
        expect(subject.referral_expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.treating_facility).to be_nil
        expect(subject.referral_number).to be_nil
        expect(subject.referral_date).to be_nil
        expect(subject.station_id).to be_nil
        expect(subject.uuid).to be_nil
        expect(subject.has_appointments).to be_nil
        expect(subject.phone_number).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.provider_npi).to be_nil
        expect(subject.provider_telephone).to be_nil
        expect(subject.referring_facility_name).to be_nil
        expect(subject.referring_facility_phone).to be_nil
        expect(subject.referring_facility_code).to be_nil
        expect(subject.referring_facility_address).to be_nil
      end
    end

    context 'when phone number comes from provider info' do
      subject { described_class.new(provider_phone_attributes) }

      let(:provider_phone_attributes) do
        {
          'Referral' => {
            'TreatingFacilityInfo' => {},
            'TreatingProviderInfo' => {
              'Telephone' => '123-456-7890'
            }
          }
        }
      end

      it 'uses provider telephone as phone_number' do
        expect(subject.phone_number).to eq('123-456-7890')
      end
    end

    context 'with APPTYesNo1 values' do
      it 'parses Y as true' do
        attributes = { 'Referral' => { 'APPTYesNo1' => 'Y' } }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be(true)
      end

      it 'parses N as false' do
        attributes = { 'Referral' => { 'APPTYesNo1' => 'N' } }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be(false)
      end

      it 'handles nil value' do
        attributes = { 'Referral' => { 'APPTYesNo1' => nil } }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be_nil
      end

      it 'handles blank value' do
        attributes = { 'Referral' => { 'APPTYesNo1' => '' } }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be_nil
      end

      it 'handles invalid value' do
        attributes = { 'Referral' => { 'APPTYesNo1' => 'X' } }
        detail = described_class.new(attributes)
        expect(detail.has_appointments).to be_nil
      end
    end
  end
end
