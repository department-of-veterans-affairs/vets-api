# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::Facilities::Client do
  let(:facilities_client) { Lighthouse::Facilities::Client.new }

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
                  'last_updated' => '2020-04-06', 'other' => [] },
      feedback: {
        'effective_date' => '2019-06-20',
        'health' => { 'specialty_care_routine' => 0.9100000262260437 }
      },
      access: {
        'effective_date' => '2020-04-06',
        'health' => [
          { 'established' => 14.352941, 'new' => 158.0, 'service' => 'Audiology' },
          { 'established' => 34.034482, 'new' => 66.75, 'service' => 'Cardiology' },
          { 'established' => 3.4, 'new' => 123.5, 'service' => 'Dermatology' },
          { 'established' => nil, 'new' => 208.0, 'service' => 'Gastroenterology' },
          { 'established' => 24.228571, 'new' => 134.222222, 'service' => 'MentalHealthCare' },
          { 'established' => 10.111111, 'new' => 154.6, 'service' => 'Ophthalmology' },
          { 'established' => 25.17647, 'new' => 122.0, 'service' => 'Orthopedics' },
          { 'established' => 18.927083, 'new' => 28.8125, 'service' => 'PrimaryCare' },
          { 'established' => 19.22807, 'new' => 75.317073, 'service' => 'SpecialtyCare' }
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

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        facilities_client.get_facilities(params)
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with a bad API key' do
    it 'returns a 401 error' do
      VCR.use_cassette('/lighthouse/facilities_401', match_requests_on: %i[path query]) do
        expect { facilities_client.get_by_id('vha_358') }
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
        r = facilities_client.get_by_id('vha_358')
        expect(r).to have_attributes(vha_358_attributes)
      end
    end

    it 'returns a 404 error' do
      VCR.use_cassette('/lighthouse/facilities', match_requests_on: %i[path query]) do
        expect { facilities_client.get_by_id('bha_358') }
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
    it 'returns matching facilities for bbox request' do
      VCR.use_cassette('/lighthouse/facilities', match_requests_on: %i[path query]) do
        r = facilities_client.get_facilities(params)
        expect(r.length).to be 8
        expect(r[0]).to have_attributes(vha_358_attributes)
      end
    end

    it 'returns matching facilities for lat and long request with distance' do
      VCR.use_cassette('/lighthouse/facilities', match_requests_on: %i[path query]) do
        r = facilities_client.get_facilities(lat: 13.54, long: 121.00)
        expect(r.length).to be 10
        expect(r[0]).to have_attributes(vha_358_attributes)
        expect(r[0].distance).to eq(69.38)
      end
    end

    it 'returns an error message for a bad param' do
      VCR.use_cassette('/lighthouse/facilities', match_requests_on: %i[path query]) do
        expect { facilities_client.get_facilities({ taco: true }) }
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
