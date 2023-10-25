# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'vaos v2 appointments', type: :request do
  include JsonSchemaMatchers

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let!(:user) { sis_user(icn: '1012846043V576341') }

  describe 'GET /mobile/v0/appointments' do
    before do
      Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z'))
    end

    after do
      Timecop.return
    end

    let(:start_date) { Time.zone.parse('2021-01-01T00:00:00Z').iso8601 }
    let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
    let(:params) { { startDate: start_date, endDate: end_date, include: ['pending'] } }

    context 'backfill facility service returns data' do
      it 'location is populated' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers, params:
            end
          end
        end
        location = response.parsed_body.dig('data', 0, 'attributes', 'location')
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(location).to eq({ 'id' => '983',
                                 'name' => 'Cheyenne VA Medical Center',
                                 'address' =>
                                   { 'street' => '2360 East Pershing Boulevard',
                                     'city' => 'Cheyenne',
                                     'state' => 'WY',
                                     'zipCode' => '82001-5356' },
                                 'lat' => 41.148026,
                                 'long' => -104.786255,
                                 'phone' =>
                                   { 'areaCode' => '307', 'number' => '778-7550',
                                     'extension' => nil },
                                 'url' => nil,
                                 'code' => nil })
      end
    end

    context 'backfill facility service returns in error' do
      it 'location is nil' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_500', match_requests_on: %i[method uri],
                                                                           allow_playback_repeats: true) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers, params:
            end
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        location = response.parsed_body.dig('data', 0, 'attributes', 'location')
        expect(location).to eq({ 'id' => nil,
                                 'name' => nil,
                                 'address' =>
                                   { 'street' => nil,
                                     'city' => nil,
                                     'state' => nil,
                                     'zipCode' => nil },
                                 'lat' => nil,
                                 'long' => nil,
                                 'phone' =>
                                   { 'areaCode' => nil,
                                     'number' => nil,
                                     'extension' => nil },
                                 'url' => nil,
                                 'code' => nil })
      end

      it 'does not attempt to fetch facility more than once' do
        expect_any_instance_of(Mobile::AppointmentsHelper).to receive(:get_facility).with('983').once

        VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_500', match_requests_on: %i[method uri],
                                                                         allow_playback_repeats: true) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_bad_facility_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: sis_headers, params:
          end
        end
      end
    end

    context 'backfill clinic service returns data' do
      it 'healthcareService is populated' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers, params:
            end
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to eq('MTZ-LAB (BLOOD WORK)')
      end
    end

    context 'backfill clinic service uses facility id that does not exist' do
      it 'healthcareService is nil' do
        allow_any_instance_of(Mobile::AppointmentsHelper).to receive(:get_clinic).and_return(nil)
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_404', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_bad_facility_id',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers, params:
            end
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to be_nil
      end

      it 'attempts to fetch clinic once' do
        allow_any_instance_of(Mobile::AppointmentsHelper).to receive(:get_clinic).and_return(nil)
        expect_any_instance_of(Mobile::AppointmentsHelper).to receive(:get_clinic).once

        VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_bad_facility_200',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers, params:
            end
          end
        end
      end
    end

    context 'when partial appointments data is received' do
      it 'has access and returned va appointments having partial errors' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_partial_error',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers, params:
            end
          end
        end

        expect(response).to have_http_status(:multi_status)
        expect(response.parsed_body['data'].count).to eq(1)
        expect(response.parsed_body['meta']).to include(
          {
            'errors' => [{ 'source' => 'VA Service' }]
          }
        )
      end
    end

    context 'request telehealth onsite appointment' do
      let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) do
        { page: { number: 1, size: 9999 }, startDate: start_date, endDate: end_date }
      end

      it 'processes appointments without error' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_telehealth_onsite',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                    tag: :force_utf8) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
        end
        attributes = response.parsed_body.dig('data', 0, 'attributes')
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('VAOS_v2_appointments')

        expect(attributes['appointmentType']).to eq('VA_VIDEO_CONNECT_ONSITE')
        expect(attributes['location']).to eq({ 'id' => '983',
                                               'name' => 'Cheyenne VA Medical Center',
                                               'address' =>
                                                { 'street' => '2360 East Pershing Boulevard',
                                                  'city' => 'Cheyenne',
                                                  'state' => 'WY',
                                                  'zipCode' => '82001-5356' },
                                               'lat' => 41.148026,
                                               'long' => -104.786255,
                                               'phone' =>
                                                { 'areaCode' => '307',
                                                  'number' => '778-7550',
                                                  'extension' => nil },
                                               'url' => nil,
                                               'code' => nil })
      end
    end

    describe 'healthcare provider names' do
      def fetch_appointments
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                    tag: :force_utf8) do
                get '/mobile/v0/appointments', headers: sis_headers
              end
            end
          end
        end
      end

      context 'when upstream appointments index returns provider names' do
        it 'adds names to healthcareProvider field' do
          fetch_appointments
          appointment = response.parsed_body['data'].find { |appt| appt['id'] == '76133' }
          expect(appointment['attributes']['healthcareProvider']).to eq('MATTHEW ENGHAUSER')
        end
      end

      context 'when the upstream appointments index returns provider id but no name' do
        let(:appointment) { response.parsed_body['data'].find { |appt| appt['id'] == '76132' } }

        it 'backfills that data by calling the provider service' do
          fetch_appointments
          expect(appointment['attributes']['healthcareProvider']).to eq('DEHGHAN, AMIR')
        end

        it 'falls back to nil when provider does not return provider data' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_400', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers
                end
              end
            end
          end
          expect(response).to have_http_status(:ok)
          expect(appointment['attributes']['healthcareProvider']).to be_nil
        end

        it 'falls back to nil when provider service returns 500' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_500', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers
                end
              end
            end
          end
          expect(response).to have_http_status(:ok)
          expect(appointment['attributes']['healthcareProvider']).to be_nil
        end
      end

      context 'when upstream appointments index provides neither provider name nor id' do
        it 'sets provider name to nil' do
          fetch_appointments
          appointment = response.parsed_body['data'].find { |appt| appt['id'] == '76131' }
          expect(appointment['attributes']['healthcareProvider']).to be_nil
        end
      end
    end
  end
end
