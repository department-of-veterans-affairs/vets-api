# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'vaos v2 appointments', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('1012846043V576341')
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:mock_clinic) do
    mock_clinic = {
      service_name: 'MTZ-LAB (BLOOD WORK)'
    }

    allow_any_instance_of(Mobile::AppointmentsHelper).to \
      receive(:get_clinic).and_return(mock_clinic)
  end

  let(:mock_facility) do
    known_ids = %w[983 984 442 508 983GC 983GB 688 516 984GA 983GD 984GD 438 620GB 984GB 442GB 442GC 442GD 983QA 984GC
                   983QE 983HK 999AA]
    mock_facility = { id: '983',
                      name: 'Cheyenne VA Medical Center',
                      timezone: {
                        time_zone_id: 'America/Denver',
                        abbreviation: 'MDT'
                      },
                      physical_address: { type: 'physical',
                                          line: ['2360 East Pershing Boulevard'],
                                          city: 'Cheyenne',
                                          state: 'WY',
                                          postal_code: '82001-5356' },
                      lat: 41.148026,
                      long: -104.786255,
                      phone: { main: '307-778-7550' },
                      url: nil,
                      code: nil }

    allow_any_instance_of(Mobile::AppointmentsHelper).to \
      receive(:get_facility).and_return(mock_facility)

    known_ids.each do |facility_id|
      allow(Rails.cache).to receive(:fetch).with("vaos_facility_#{facility_id}",
                                                 {
                                                   expires_in: 12.hours
                                                 }).and_return(mock_facility.merge(id: facility_id))
    end
  end

  let(:provider_response) do
    OpenStruct.new({ 'providerIdentifier' => '1407938061', 'name' => 'DEHGHAN, AMIR' })
  end

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
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params:
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
                                 'lat' => 39.744507,
                                 'long' => -104.830956,
                                 'phone' =>
                                   { 'areaCode' => '307', 'number' => '778-7550',
                                     'extension' => nil },
                                 'url' => nil,
                                 'code' => nil })
      end
    end

    context 'backfill facility service returns in error' do
      it 'location is nil' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_500', match_requests_on: %i[method uri],
                                                                           allow_playback_repeats: true) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params:
            end
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body['location']).to be_nil
      end
    end

    context 'backfill clinic service returns data' do
      it 'healthcareService is populated' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params:
            end
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to eq('MTZ-LAB (BLOOD WORK)')
      end
    end

    context 'backfill clinic service uses facility id that does not exist' do
      before { mock_facility }

      it 'healthcareService is nil' do
        allow_any_instance_of(Mobile::AppointmentsHelper).to receive(:get_clinic).and_return(nil)
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_bad_facility_id',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params:
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to be_nil
      end
    end

    context 'when partial appointments data is received' do
      it 'has access and returned va appointments having partial errors' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_partial_error',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params:
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

    context 'request all appointments without requests' do
      before do
        mock_facility
        mock_clinic
      end

      let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) { { page: { number: 1, size: 100 }, startDate: start_date, endDate: end_date } }

      it 'returns no appointment requests' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_all_appointment_200_ruben',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
            allow_any_instance_of(Mobile::V2::Appointments::ProviderNames).to \
              receive(:fetch_provider).and_return(provider_response)
            get '/mobile/v0/appointments', headers: iam_headers, params:
          end
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('VAOS_v2_appointments')

        uniq_statuses = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'status') }.uniq
        expect(uniq_statuses).to match_array(%w[BOOKED])

        proposed_times = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'proposedTimes') }.uniq
        expect(proposed_times).to eq([nil])

        is_pending = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'isPending') }.uniq
        expect(is_pending).to eq([false])
      end
    end

    context 'request all appointments with requests' do
      before do
        mock_facility
        mock_clinic
      end

      let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) do
        { page: { number: 1, size: 9999 }, startDate: start_date, endDate: end_date, include: ['pending'] }
      end

      it 'processes appointments without error' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_all_appointment_200_ruben',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
            allow_any_instance_of(Mobile::V2::Appointments::ProviderNames).to \
              receive(:fetch_provider).and_return(provider_response)
            get '/mobile/v0/appointments', headers: iam_headers, params:
          end
        end
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data'].size).to eq(980)
        # VAOS v2 appointment is only different from appointments by allowing some fields to be nil.
        # This is due to bad staging data.
        expect(response.body).to match_json_schema('VAOS_v2_appointments')

        uniq_statuses = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'status') }.uniq
        expect(uniq_statuses).to match_array(%w[CANCELLED BOOKED SUBMITTED])

        proposed_times = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'proposedTimes') }.uniq
        expect(proposed_times).not_to eq([nil])

        is_pending = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'isPending') }.uniq
        expect(is_pending).to match_array([true, false])
      end
    end

    context 'request telehealth onsite appointment' do
      before do
        mock_facility
        mock_clinic
      end

      let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) do
        { page: { number: 1, size: 9999 }, startDate: start_date, endDate: end_date }
      end

      it 'processes appointments without error' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_telehealth_onsite',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
            allow_any_instance_of(Mobile::V2::Appointments::ProviderNames).to \
              receive(:fetch_provider).and_return(provider_response)
            get '/mobile/v0/appointments', headers: iam_headers, params:
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
      before do
        mock_facility
        mock_clinic
      end

      def fetch_appointments
        VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
            allow_any_instance_of(Mobile::V2::Appointments::ProviderNames).to \
              receive(:fetch_provider).with('1407938061').and_return(provider_response)
            get '/mobile/v0/appointments', headers: iam_headers
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
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/providers/get_provider_400', match_requests_on: %i[method uri],
                                                                  tag: :force_utf8) do
              allow_any_instance_of(Mobile::V2::Appointments::ProviderNames).to receive(:fetch_provider).and_return(nil)
              get '/mobile/v0/appointments', headers: iam_headers
            end
          end
          expect(response).to have_http_status(:ok)
          expect(appointment['attributes']['healthcareProvider']).to be_nil
        end

        it 'falls back to nil when provider service returns 500' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/providers/get_provider_500', match_requests_on: %i[method uri],
                                                                  tag: :force_utf8) do
              allow_any_instance_of(Mobile::V2::Appointments::ProviderNames).to receive(:fetch_provider).and_return(nil)
              get '/mobile/v0/appointments', headers: iam_headers
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
