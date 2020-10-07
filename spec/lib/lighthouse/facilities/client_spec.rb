# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/client'

RSpec.describe Lighthouse::Facilities::Client do
  vcr_options = {
    match_requests_on: %i[path query],
    allow_playback_repeats: true,
    record: :new_episodes
  }

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
      lat: 14.54408,
      long: 120.99139,
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
        'after_hours' => nil,
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
      services: { 'health' => %w[Audiology Cardiology Dermatology Ophthalmology
                                 PrimaryCare SpecialtyCare],
                  'last_updated' => '2020-09-14', 'other' => [] },
      feedback: {
        'effective_date' => nil,
        'health' => {}
      },
      access: {
        'effective_date' => '2020-09-14',
        'health' => [
          { 'established' => 29.705882, 'new' => 68.857142, 'service' => 'Audiology' },
          { 'established' => 29.108695, 'new' => 2.2,       'service' => 'Cardiology' },
          { 'established' => 7.153846,  'new' => 81.714285, 'service' => 'Dermatology' },
          { 'established' => 28.462962, 'new' => 98.222222, 'service' => 'Ophthalmology' },
          { 'established' => 15.333333, 'new' => 7.0,       'service' => 'PrimaryCare' },
          { 'established' => 26.449197, 'new' => 61.53125,  'service' => 'SpecialtyCare' }
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

  context 'with a bad API key', vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities_401') do
    it 'returns a 401 error' do
      expect { facilities_client.get_by_id('vha_358') }
        .to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::BackendServiceException)
        expect(e.status_code).to eq(401)
        expect(e.errors.first[:detail]).to eq('Invalid authentication credentials')
        expect(e.errors.first[:code]).to eq('LIGHTHOUSE_FACILITIES401')
      end
    end
  end

  describe '#get_by_id', vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
    it 'returns a facility' do
      r = facilities_client.get_by_id('vha_358')
      expect(r).to have_attributes(vha_358_attributes)
    end

    it 'returns a 404 error' do
      expect { facilities_client.get_by_id('bha_358') }
        .to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::BackendServiceException)
        expect(e.status_code).to eq(404)
        expect(e.errors.first[:detail]).to eq('Record not found')
        expect(e.errors.first[:code]).to eq('LIGHTHOUSE_FACILITIES404')
      end
    end
  end

  describe '#get_facilities', vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
    it 'returns matching facilities for bbox request' do
      r = facilities_client.get_facilities(params)
      expect(r.length).to be 8
      expect(r[0]).to have_attributes(vha_358_attributes)
    end

    it 'returns matching facilities for lat and long request with distance' do
      r = facilities_client.get_facilities(lat: 13.54, long: 121.00)
      expect(r.length).to be 10
      expect(r[0]).to have_attributes(vha_358_attributes)
      expect(r[0].distance).to eq(69.38)
    end

    it 'returns an error message for a bad param' do
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
