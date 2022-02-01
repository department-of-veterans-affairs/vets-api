# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: '/facilities/va/lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe FacilitiesApi::V1::Lighthouse::Client, team: :facilities, vcr: vcr_options do
  let(:facilities_client) { described_class.new }

  let(:params) do
    {
      bbox: [60.99, 10.54, 180.00, 20.55] # includes the Phillipines and Guam
    }
  end

  let(:last_updated) { '2022-01-23' }

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
        'enrollment_coordinator' => '808-433-5254',
        'fax' => nil,
        'main' => '808-433-5254',
        'patient_advocate' => '808-433-5254',
        'pharmacy' => '808-433-5254'
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
      services: { 'health' => %w[Audiology Cardiology Dermatology Gastroenterology
                                 MentalHealthCare Ophthalmology SpecialtyCare],
                  'last_updated' => last_updated, 'other' => [] },
      feedback: {
        'effective_date' => '2021-03-05',
        'health' => {
          'primary_care_urgent' => 0.0,
          'primary_care_routine' => 0.9100000262260437,
          'specialty_care_urgent' => 0.0,
          'specialty_care_routine' => 0.0
        }
      },
      access: {
        'effective_date' => last_updated,
        'health' => [
          { service: 'Audiology',         new: 27.823529, established: 25.65 },
          { service: 'Cardiology',        new: 60.75,     established: 53.222222  },
          { service: 'Dermatology',       new: 58.0,      established: 113.166666 },
          { service: 'Gastroenterology',  new: 33.0,      established: nil },
          { service: 'MentalHealthCare',  new: 35.923076, established: 36.4 },
          { service: 'Ophthalmology',     new: 98.363636, established: 52.439024 },
          { service: 'SpecialtyCare',     new: 65.57931,  established: 15.320448 }
        ]
      },
      mobile: false,
      active_status: 'A',
      visn: '21',
      operating_status: { 'code' => 'NORMAL' },
      operational_hours_special_instructions: nil,
      facility_type_prefix: 'vha',
      unique_id: '358'
    }.with_indifferent_access
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

  context 'StatsD notifications' do
    context 'Lighthouse responds Successfully' do
      it "sends a 'facilities.lighthouse.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(
          'facilities.lighthouse.response.total',
          hash_including(
            tags: [
              'http_status:200'
            ]
          )
        )

        expect do
          FacilitiesApi::V1::Lighthouse::Client.new.get_facilities(params)
        end.to instrument('lighthouse.facilities.v1.request.faraday')
      end
    end

    context 'Lighthouse responds with a Failure', vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities_401') do
      it "sends a 'facilities.lighthouse.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(
          'facilities.lighthouse.response.total',
          hash_including(
            tags: [
              'http_status:401'
            ]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.lighthouse.response.failures',
          hash_including(
            tags: [
              'http_status:401'
            ]
          )
        )

        expect do
          FacilitiesApi::V1::Lighthouse::Client.new.get_by_id('vha_358')
        end.to raise_error(
          Common::Exceptions::BackendServiceException
        ).and instrument('lighthouse.facilities.v1.request.faraday')
      end
    end
  end

  describe '#get_by_id' do
    it 'returns a facility' do
      r = facilities_client.get_by_id('vha_358')
      expect(r).to have_attributes(vha_358_attributes)
    end

    it 'has operational_hours_special_instructions' do
      r = facilities_client.get_by_id('vc_0617V')
      expect(r[:operational_hours_special_instructions]).to eql('More hours are available for some services. To ' \
                                                                'learn more, call our main phone number. | If you ' \
                                                                'need to talk to someone or get advice right away, ' \
                                                                'call the Vet Center anytime at 1-877-WAR-VETS ' \
                                                                '(1-877-927-8387).')
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

  describe '#get_facilities' do
    it 'returns matching facilities for bbox request' do
      r = facilities_client.get_facilities(params)
      expect(r.length).to be 8
      expect(r[1]).to have_attributes(vha_358_attributes)
    end

    it 'returns matching facilities for lat and long request with distance' do
      r = facilities_client.get_facilities(lat: 13.54, long: 121.00)
      expect(r.length).to be 10
      expect(r[1]).to have_attributes(vha_358_attributes)
      expect(r[1].distance).to eq(69.38)
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
