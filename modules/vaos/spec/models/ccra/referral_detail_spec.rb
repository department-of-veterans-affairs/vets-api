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
          'TreatingProvider' => 'Dr. Smith',
          'TreatingFacility' => 'VA Medical Center',
          'ReferralNumber' => 'VA0000005681',
          'network' => 'Veteran Affairs Payment',
          'networkCode' => 'VA',
          'referralConsultId' => '984_646907',
          'referralDate' => '2024-07-24',
          'referralLastUpdateDateTime' => '2024-07-25T10:30:00',
          'referringFacility' => 'Bath VA Medical Center',
          'referringProvider' => 'ERMIAS YIRGA',
          'seocId' => 'MSC_CARDIOLOGY_1.4.17_REV_PRCT',
          'seocKey' => '23',
          'serviceRequested' => 'Cardiology_REV_PRCT SEOC 1.4.17',
          'sourceOfReferral' => 'Interfaced from VA',
          'sta6' => '534',
          'stationId' => '528A6',
          'status' => 'Sent',
          'treatingFacilityFax' => 'na',
          'treatingFacilityPhone' => '505-248-4062',
          'appointments' => [
            {
              'appointmentCreateDateTime' => '2024-05-01 17:08:17',
              'appointmentDate' => '2025-05-07',
              'appointmentFor' => 'Anesthesia consultation',
              'appointmentStatus' => 'X',
              'appointmentTime' => '13:00:00'
            }
          ],
          'referringFacilityInfo' => {
            'description' => 'Bath VA Medical Center',
            'facilityCode' => '528A6'
          },
          'referringProviderInfo' => {
            'providerName' => 'ERMIAS YIRGA',
            'providerNpi' => '534_520824797'
          },
          'treatingProviderInfo' => {
            'providerName' => 'Albuquerque Indian Health Center',
            'providerNpi' => '1659458917'
          },
          'treatingFacilityInfo' => {
            'facilityName' => 'Albuquerque Indian Health Center (IHS)'
          },
          'treatingFacilityAddress' => {
            'address1' => '801 VASSAR DR NE',
            'city' => 'ALBUQUERQUE'
          }
        }
      }
    end

    it 'sets all attributes correctly' do
      # Original attributes
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.type_of_care).to eq('CARDIOLOGY')
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.location).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')

      # New simple attributes
      expect(subject.network).to eq('Veteran Affairs Payment')
      expect(subject.network_code).to eq('VA')
      expect(subject.referral_consult_id).to eq('984_646907')
      expect(subject.referral_date).to eq('2024-07-24')
      expect(subject.referral_last_update_datetime).to eq('2024-07-25T10:30:00')
      expect(subject.referring_facility).to eq('Bath VA Medical Center')
      expect(subject.referring_provider).to eq('ERMIAS YIRGA')
      expect(subject.seoc_id).to eq('MSC_CARDIOLOGY_1.4.17_REV_PRCT')
      expect(subject.seoc_key).to eq('23')
      expect(subject.service_requested).to eq('Cardiology_REV_PRCT SEOC 1.4.17')
      expect(subject.source_of_referral).to eq('Interfaced from VA')
      expect(subject.sta6).to eq('534')
      expect(subject.station_id).to eq('528A6')
      expect(subject.status).to eq('Sent')
      expect(subject.treating_facility).to eq('VA Medical Center')
      expect(subject.treating_facility_fax).to eq('na')
      expect(subject.treating_facility_phone).to eq('505-248-4062')

      # Complex nested objects
      expect(subject.appointments).to be_an(Array)
      expect(subject.appointments.first).to include('appointmentDate' => '2025-05-07')
      expect(subject.referring_facility_info).to include('facilityCode' => '528A6')
      expect(subject.referring_provider_info).to include('providerNpi' => '534_520824797')
      expect(subject.treating_provider_info).to include('providerNpi' => '1659458917')
      expect(subject.treating_facility_info).to include('facilityName' => 'Albuquerque Indian Health Center (IHS)')
      expect(subject.treating_facility_address).to include('city' => 'ALBUQUERQUE')
    end

    context 'with missing Referral key' do
      subject { described_class.new(attributes_without_referral) }

      let(:attributes_without_referral) do
        {}
      end

      it 'sets all attributes to nil' do
        # Original attributes
        expect(subject.expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.location).to be_nil
        expect(subject.referral_number).to be_nil

        # New simple attributes
        expect(subject.network).to be_nil
        expect(subject.network_code).to be_nil
        expect(subject.referral_consult_id).to be_nil
        expect(subject.referral_date).to be_nil
        expect(subject.referring_facility).to be_nil
        expect(subject.status).to be_nil

        # Complex nested objects - just checking a few as examples
        expect(subject.appointments).to be_nil
        expect(subject.referring_facility_info).to be_nil
        expect(subject.treating_facility_address).to be_nil
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
        expect(subject.type_of_care).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.location).to be_nil
        expect(subject.referral_number).to be_nil

        # New simple attributes
        expect(subject.network).to be_nil
        expect(subject.network_code).to be_nil
        expect(subject.referral_consult_id).to be_nil
        expect(subject.referral_date).to be_nil
        expect(subject.referring_facility).to be_nil
        expect(subject.status).to be_nil

        # Complex nested objects - just checking a few as examples
        expect(subject.appointments).to be_nil
        expect(subject.referring_facility_info).to be_nil
        expect(subject.treating_facility_address).to be_nil
      end
    end
  end
end
