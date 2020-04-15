# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::Facilities::Client do
  let(:params) do
    {
      bbox: [60.99, 10.54, 180.00, 20.55] # includes the Phillipines and Guam
    }
  end

  let(:vha_358_attributes) do
    {
      id: 'vha_358',
      type: 'va_facilities',
      name: 'Manila VA Clinic',
      facility_type: 'va_health_facility',
      classification: 'Other Outpatient Services (OOS)',
      website: nil,
      lat: 14.544080000000065,
      long: 120.99139000000002,
      address: {
        'mailing' => {},
        'physical' => {
          'address_1' => '1501 Roxas Boulevard',
          'address_2' => 'NOX3 Seafront Compound',
          'address_3' => nil,
          'city' => 'Pasay City',
          'state' => 'PH',
          'zip' => '01302'
        }
      },
      phone: {
        'after_hours' => '000-000-0000',
        'enrollment_coordinator' => '632-550-3888 x3780',
        'fax' => '632-310-5962',
        'main' => '632-550-3888',
        'patient_advocate' => '632-550-3888 x3716',
        'pharmacy' => '632-550-3888 x5029'
      },
      hours: {
        'friday' => '730AM-430PM',
        'monday' => '730AM-430PM',
        'saturday' => 'Closed',
        'sunday' => 'Closed',
        'thursday' => '730AM-430PM',
        'tuesday' => '730AM-430PM',
        'wednesday' => '730AM-430PM'
      },
      services: { 'health' => %w[Audiology Cardiology Dermatology EmergencyCare Gastroenterology
                                 MentalHealthCare Ophthalmology Orthopedics PrimaryCare SpecialtyCare],
                  'last_updated' => '2020-03-30', 'other' => [] },
      feedback: {
        'effective_date' => '2019-06-20',
        'health' => { 'specialty_care_routine' => 0.9100000262260437 }
      },
      access: {
        'effective_date' => '2020-03-30',
        'health' => [
          { 'established' => 25.0, 'new' => 139.0, 'service' => 'Audiology' },
          { 'established' => 34.944444, 'new' => 66.0, 'service' => 'Cardiology' },
          { 'established' => 2.583333, 'new' => 103.5, 'service' => 'Dermatology' },
          { 'established' => nil, 'new' => 104.0, 'service' => 'Gastroenterology' },
          { 'established' => 26.101351, 'new' => 103.333333, 'service' => 'MentalHealthCare' },
          { 'established' => 12.864864, 'new' => 137.0, 'service' => 'Ophthalmology' },
          { 'established' => 21.325, 'new' => 136.9, 'service' => 'Orthopedics' },
          { 'established' => 16.7266, 'new' => 21.566666, 'service' => 'PrimaryCare' },
          { 'established' => 22.189427, 'new' => 70.949367, 'service' => 'SpecialtyCare' }
        ]
      },
      mobile: false,
      active_status: 'A',
      visn: '21',
      operating_status: { 'code' => 'NORMAL' },
      facility_type_prefix: 'vha',
      unique_id: '358'
    }
  end

  it 'is an Facilities::Client object' do
    facilities_client = described_class.new(Settings.lighthouse.api_key)
    expect(facilities_client).to be_an(Lighthouse::Facilities::Client)
    expect(facilities_client).to have_attributes(headers: { 'apikey' => Settings.lighthouse.api_key })
  end

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        Lighthouse::Facilities::Client.new(Settings.lighthouse.api_key).get_facilities(params)
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with a bad API key' do
    it 'returns a 401 error' do
      VCR.use_cassette('/lighthouse/facilities_401', match_requests_on: %i[path query]) do
        expect { Lighthouse::Facilities::Client.new('bad_key').get_by_id('vha_358') }
          .to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(401)
          expect(e.errors.first[:detail]).to eq('Invalid authentication credentials')
          expect(e.errors.first[:code]).to eq('LIGHTHOUSE_FACILITIES401')
        end
      end
    end
  end

  describe '#get_by_id' do
    it 'returns a facility' do
      VCR.use_cassette('/lighthouse/facilities', match_requests_on: %i[path query]) do
        r = Lighthouse::Facilities::Client.new(Settings.lighthouse.api_key).get_by_id('vha_358')
        expect(r).to have_attributes(vha_358_attributes)
      end
    end

    it 'returns a 401 error' do
      VCR.use_cassette('/lighthouse/facilities', record: :new_episodes, match_requests_on: %i[path query]) do
        expect { Lighthouse::Facilities::Client.new(Settings.lighthouse.facilities.api_key).get_by_id('bha_358') }
          .to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(404)
          expect(e.errors.first[:detail]).to eq('Record not found')
          expect(e.errors.first[:code]).to eq('LIGHTHOUSE_FACILITIES404')
        end
      end
    end
  end

  describe '#get_facilities' do
    it 'returns matching facilities' do
      VCR.use_cassette('/lighthouse/facilities', record: :new_episodes, match_requests_on: %i[path query]) do
        r = Lighthouse::Facilities::Client.new(Settings.lighthouse.api_key).get_facilities(params)
        expect(r.length).to be 8
        expect(r[0]).to have_attributes(vha_358_attributes)
      end
    end

    it 'returns an error message for a bad param' do
      VCR.use_cassette('/lighthouse/facilities', record: :new_episodes, match_requests_on: %i[path query]) do
        expect { Lighthouse::Facilities::Client.new(Settings.lighthouse.facilities.api_key).get_facilities({ taco: true }) }
          .to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first[:detail]).to eq('Bad Request')
          expect(e.errors.first[:code]).to eq('LIGHTHOUSE_FACILITIES400')
        end
      end
    end
  end
end
