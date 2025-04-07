# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: '/facilities/va/lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe FacilitiesApi::V2::Lighthouse::Client, team: :facilities, vcr: vcr_options do
  let(:facilities_client) { described_class.new }

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
      parent: {
        id: 'vha_358',
        link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358'
      },
      lat: 14.54408,
      long: 120.99139,
      time_zone: 'Asia/Manila',
      address: {
        physical: {
          zip: '01302',
          city: 'Pasay City',
          state: 'PH',
          address1: '1501 Roxas Boulevard',
          address2: 'NOX3 Seafront Compound'
        }
      },
      phone: {
        main: '808-433-5254',
        pharmacy: '808-433-5254',
        patientAdvocate: '808-433-5254',
        enrollmentCoordinator: '808-433-5254'
      },
      hours: {
        monday: '730AM-430PM',
        tuesday: '730AM-430PM',
        wednesday: '730AM-430PM',
        thursday: '730AM-430PM',
        friday: '730AM-430PM',
        saturday: 'Closed',
        sunday: 'Closed'
      },
      services: {
        health: [
          {
            name: 'Audiology',
            serviceId: 'audiology',
            link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services/audiology'
          },
          {
            name: 'Cardiology',
            serviceId: 'cardiology',
            link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services/cardiology'
          },
          {
            name: 'Dermatology',
            serviceId: 'dermatology',
            link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services/dermatology'
          },
          {
            name: 'Gastroenterology',
            serviceId: 'gastroenterology',
            link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services/gastroenterology'
          },
          {
            name: 'MentalHealth',
            serviceId: 'mentalHealth',
            link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services/mentalHealth'
          },
          {
            name: 'Ophthalmology',
            serviceId: 'ophthalmology',
            link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services/ophthalmology'
          }
        ],
        link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_358/services',
        lastUpdated: '2024-04-17'
      },
      feedback: {
        health: {
          specialtyCareUrgent: 0.0,
          specialtyCareRoutine: 0.8399999737739563
        },
        effectiveDate: '2024-02-08'
      },
      mobile: false,
      operating_status: {
        code: 'NORMAL'
      },
      visn: '21'
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
    context 'Lighthouse responds successfully' do
      it "sends a 'facilities.lighthouse.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(
          'facilities.lighthouse.v2.response.total',
          hash_including(
            tags: [
              'http_status:200'
            ]
          )
        )

        expect do
          FacilitiesApi::V2::Lighthouse::Client.new.get_facilities(params)
        end.to instrument('lighthouse.facilities.v2.request.faraday')
      end
    end

    context 'Lighthouse responds with a failure', vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities_401') do
      it "sends a 'facilities.lighthouse.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(
          'facilities.lighthouse.v2.response.total',
          hash_including(
            tags: [
              'http_status:401'
            ]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.lighthouse.v2.response.failures',
          hash_including(
            tags: [
              'http_status:401'
            ]
          )
        )

        expect do
          FacilitiesApi::V2::Lighthouse::Client.new.get_by_id('vha_358')
        end.to raise_error(
          Common::Exceptions::BackendServiceException
        ).and instrument('lighthouse.facilities.v2.request.faraday')
      end
    end
  end

  describe '#get_by_id' do
    it 'returns a facility' do
      r = facilities_client.get_by_id('vha_358')
      expect(r).to be_a(FacilitiesApi::V2::Lighthouse::Facility)
      expect(r).to have_attributes(vha_358_attributes)
    end

    it 'has operational_hours_special_instructions' do
      r = facilities_client.get_by_id('vc_0617V')
      instructions = ['More hours are available for some services. To learn more, call our main phone number.',
                      'If you need to talk to someone or get advice right away, call the Vet Center anytime at ' \
                      '1-877-WAR-VETS (1-877-927-8387).']
      expect(r[:operational_hours_special_instructions]).to eql(instructions)
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
      expect(r.length).to be 9
      expect(r[1]).to have_attributes(vha_358_attributes)
    end

    it 'returns matching facilities for lat and long request with distance' do
      r = facilities_client.get_facilities(lat: 13.54, long: 121.00)
      expect(r.length).to be 10
      expect(r[1]).to have_attributes(vha_358_attributes)
      expect(r[1].distance).to eq(69.38)
    end

    it 'returns all facilities when a bad param is supplied' do
      r = facilities_client.get_facilities({ taco: true })
      expect(r.length).to be 10
      expect(r[0]).to be_a(FacilitiesApi::V2::Lighthouse::Facility)
    end
  end

  describe '#get_paginated_facilities' do
    it 'returns full facilities response object for request' do
      meta = {
        'pagination' => {
          'currentPage' => 1,
          'perPage' => 10,
          'totalPages' => 1,
          'totalEntries' => 9
        }
      }

      r = facilities_client.get_paginated_facilities(params)
      expect(r).to be_a(FacilitiesApi::V2::Lighthouse::Response)
      expect(r.facilities).to be_an(Array)
      expect(r.meta).to eq meta
    end
  end
end
