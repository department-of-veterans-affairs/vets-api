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
            'FacilityName' => 'Dayton VA Medical Center',
            'Phone' => '(937) 262-3800',
            'FacilityCode' => '552',
            'Address' => {
              'Address1' => '4100 West Third Street',
              'City' => 'DAYTON',
              'State' => 'OH',
              'ZipCode' => '45428'
            }
          },
          'TreatingFacilityInfo' => {
            'Phone' => '555-123-4567'
          },
          'TreatingProviderInfo' => {
            'ProviderName' => 'Dr. Smith',
            'ProviderNPI' => '1234567890',
            'Telephone' => '555-987-6543'
          }
        }
      }
    end

    it 'sets all attributes correctly' do
      # Original attributes
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.referral_expiration_date).to eq('2024-05-27')
      expect(subject.type_of_care).to eq('CARDIOLOGY')
      expect(subject.referral_number).to eq('VA0000005681')
      expect(subject.referral_date).to eq('2024-07-24')
      expect(subject.station_id).to eq('528A6')
      expect(subject.phone_number).to eq('555-123-4567')
      expect(subject.has_appointments).to be(true)

      # Treating provider info
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.provider_npi).to eq('1234567890')
      expect(subject.provider_telephone).to eq('555-987-6543')
      expect(subject.treating_facility).to eq('VA Medical Center')

      # Referring facility info
      expect(subject.referring_facility_name).to eq('Dayton VA Medical Center')
      expect(subject.referring_facility_phone).to eq('(937) 262-3800')
      expect(subject.referring_facility_code).to eq('552')

      # Referring facility address
      expect(subject.referring_facility_address).to be_a(Hash)
      expect(subject.referring_facility_address[:street1]).to eq('4100 West Third Street')
      expect(subject.referring_facility_address[:city]).to eq('DAYTON')
      expect(subject.referring_facility_address[:state]).to eq('OH')
      expect(subject.referring_facility_address[:zip]).to eq('45428')
    end

    context 'with missing Referral key' do
      subject { described_class.new(attributes_without_referral) }

      let(:attributes_without_referral) do
        {}
      end

      it 'sets all attributes to nil' do
        # Original attributes
        expect(subject.expiration_date).to be_nil
        expect(subject.referral_expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.provider_npi).to be_nil
        expect(subject.provider_telephone).to be_nil
        expect(subject.treating_facility).to be_nil
        expect(subject.referral_number).to be_nil
        expect(subject.referral_date).to be_nil
        expect(subject.station_id).to be_nil
        expect(subject.has_appointments).to be_nil

        # Referring facility info
        expect(subject.referring_facility_name).to be_nil
        expect(subject.referring_facility_address).to be_nil
      end
    end

    context 'with nil Referral value' do
      subject { described_class.new(attributes_with_nil_referral) }

      let(:attributes_with_nil_referral) do
        { 'Referral' => nil }
      end

      it 'sets all attributes to nil' do
        # Original attributes
        expect(subject.expiration_date).to be_nil
        expect(subject.referral_expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.provider_npi).to be_nil
        expect(subject.provider_telephone).to be_nil
        expect(subject.treating_facility).to be_nil
        expect(subject.referral_number).to be_nil
        expect(subject.referral_date).to be_nil
        expect(subject.station_id).to be_nil
        expect(subject.has_appointments).to be_nil

        # Referring facility info
        expect(subject.referring_facility_name).to be_nil
        expect(subject.referring_facility_address).to be_nil
      end
    end
  end
end
