# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'vaos v2 appointments', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('1012846043V576341')
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  let(:mock_clinic) do
    mock_clinic = {
      service_name: 'Friendly Name Optometry'
    }

    allow_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_clinic).and_return(mock_clinic)
  end

  let(:mock_facility) do
    mock_facility = { id: '983',
                      name: 'Cheyenne VA Medical Center',
                      time_zone: {
                        time_zone_id: 'America/Denver'
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

    allow_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_facility).and_return(mock_facility)
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/appointments' do
    before do
      Flipper.enable(:mobile_appointment_use_VAOS_v2)
      Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z'))
    end

    after do
      Flipper.disable(:mobile_appointment_use_VAOS_v2)
      Timecop.return
    end

    let(:start_date) { Time.zone.parse('2021-01-01T00:00:00Z').iso8601 }
    let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
    let(:params) { { startDate: start_date, endDate: end_date, include: ['pending'] } }

    context 'backfill facility service returns data' do
      before { mock_clinic }

      it 'location is populated' do
        VCR.use_cassette('appointments/VAOS_v2/get_facility_200',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params: params
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
      before { mock_clinic }

      it 'location is nil' do
        VCR.use_cassette('appointments/VAOS_v2/get_facility_500',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params: params
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body['location']).to be_nil
      end
    end

    context 'backfill clinic service returns data' do
      before { mock_facility }

      it 'healthcareService is populated' do
        VCR.use_cassette('appointments/VAOS_v2/get_clinic_200',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params: params
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to eq('MTZ-LAB (BLOOD WORK)')
      end
    end

    context 'backfill clinic service uses facility id that does not exist' do
      before { mock_facility }

      it 'healthcareService is nil' do
        VCR.use_cassette('appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200_bad_facility_id',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params: params
          end
        end
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
        expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to be_nil
      end
    end

    context 'request VAOS v2 VA appointment' do
      before do
        mock_facility
        mock_clinic
      end

      it 'returned appointment is identical to VAOS v0 version' do
        VCR.use_cassette('appointments/VAOS_v2/get_appointment_200',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
        appt_v0_cancelled = JSON.parse(File.read(Rails.root.join('modules', 'mobile', 'spec', 'support',
                                                                 'fixtures', 'va_v0_appointment.json')))
        response_v2 = response.parsed_body.dig('data', 0)

        expect(response.body).to match_json_schema('appointments')

        # removed vetextId due to lack of use on FE
        expect(response_v2['attributes'].except('vetextId')).to eq(appt_v0_cancelled['attributes'].except('vetextId'))
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
        VCR.use_cassette('appointments/VAOS_v2/get_all_appointment_200_ruben',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
            get '/mobile/v0/appointments', headers: iam_headers, params: params
          end
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('VAOS_v2_appointments')

        uniq_statuses = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'status') }.uniq
        expect(uniq_statuses).to match_array(%w[BOOKED CANCELLED])

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
        VCR.use_cassette('appointments/VAOS_v2/get_all_appointment_200_ruben',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
            get '/mobile/v0/appointments', headers: iam_headers, params: params
          end
        end
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data'].size).to eq(1305)
        # VAOS v2 appointment is only different from appointments by allowing some fields to be nil.
        # This is due to bad staging data.
        expect(response.body).to match_json_schema('VAOS_v2_appointments')

        uniq_statuses = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'status') }.uniq
        expect(uniq_statuses).to match_array(%w[CANCELLED BOOKED SUBMITTED])

        proposed_times = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'proposedTimes') }.uniq
        expect(proposed_times).not_to eq([nil])

        is_pending = response.parsed_body['data'].map { |appt| appt.dig('attributes', 'isPending') }.uniq
        expect(is_pending).to eq([true, false])
      end
    end

    describe 'healthcare provider names' do
      before do
        mock_facility
        mock_clinic
      end

      def fetch_appointments
        VCR.use_cassette('appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                         match_requests_on: %i[method uri]) do
          VCR.use_cassette('providers/get_provider_200', match_requests_on: %i[method uri], tag: :force_utf8) do
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

        it 'logs error and falls back to nil when provider does not return provider data' do
          expect(Rails.logger).to receive(:error).with('Mobile appointments provider not found', '1407938061')

          VCR.use_cassette('appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('providers/get_provider_400', match_requests_on: %i[method uri], tag: :force_utf8) do
              get '/mobile/v0/appointments', headers: iam_headers
            end
          end
          expect(response).to have_http_status(:ok)
          expect(appointment['attributes']['healthcareProvider']).to be_nil
        end

        it 'logs error and falls back to nil when provider service returns 500' do
          VCR.use_cassette('appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('providers/get_provider_500', match_requests_on: %i[method uri], tag: :force_utf8) do
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
