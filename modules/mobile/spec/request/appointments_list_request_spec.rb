# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointments', type: :request do
  include JsonSchemaMatchers

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/appointments' do
    before do
      Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
    end

    after { Timecop.return }

    context 'with a missing params' do
      before do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: nil
            end
          end
        end
      end

      it 'defaults to a range of -1 year and +1 year' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with an invalid date in params' do
      let(:start_date) { 42 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date, useCache: true } }

      it 'returns a bad request error' do
        get '/mobile/v0/appointments', headers: iam_headers, params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq(
          {
            'errors' => [
              {
                'title' => 'Validation Error',
                'detail' => 'start_date must be a date time',
                'code' => 'MOBL_422_validation_error', 'status' => '422'
              }
            ]
          }
        )
      end
    end

    context 'with an invalid pagination params' do
      let(:start_date) { (Time.now.utc - 3.months).iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:page) { { number: 'one', size: 'ten' } }
      let(:params) { { startDate: start_date, endDate: end_date, useCache: true, page: page } }

      it 'returns a bad request error' do
        get '/mobile/v0/appointments', headers: iam_headers, params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq(
          {
            'errors' => [
              { 'title' => 'Validation Error', 'detail' => 'page_number must be an integer',
                'code' => 'MOBL_422_validation_error', 'status' => '422' },
              { 'title' => 'Validation Error', 'detail' => 'page_size must be an integer',
                'code' => 'MOBL_422_validation_error', 'status' => '422' }
            ]
          }
        )
      end
    end

    context 'with valid params when there are cached appointments' do
      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date, page: { number: 1, size: 10 }, useCache: true } }
      let(:user) { build(:iam_user) }

      before do
        va_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments.json')
        cc_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'cc_appointments.json')
        va_json = File.read(va_path)
        cc_json = File.read(cc_path)
        va_appointments = Mobile::V0::Adapters::VAAppointments.new.parse(
          JSON.parse(va_json, symbolize_names: true)
        )[0]
        cc_appointments = Mobile::V0::Adapters::CommunityCareAppointments.new.parse(
          JSON.parse(cc_json, symbolize_names: true)
        )

        appointments = (va_appointments + cc_appointments).sort_by(&:start_date_utc)
        Mobile::V0::Appointment.set_cached(user, appointments)
      end

      after { Timecop.return }

      it 'retrieves the cached appointments rather than hitting the service' do
        expect_any_instance_of(VAOS::AppointmentService).not_to receive(:get_appointments)
        get '/mobile/v0/appointments', headers: iam_headers, params: params
        expect(response).to have_http_status(:ok)
      end

      describe 'pagination' do
        context 'when the first page is requested' do
          let(:params) { { startDate: start_date, endDate: end_date, page: { number: 1, size: 5 }, useCache: true } }

          before { get '/mobile/v0/appointments', headers: iam_headers, params: params }

          it 'has 10 items' do
            expect(response.parsed_body['data'].size).to eq(5)
          end

          it 'has the correct links with no prev' do
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=1&page[size]=5',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=1&page[size]=5',
                'prev' => nil,
                'next' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=2&page[size]=5',
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=4&page[size]=5'
              }
            )
          end

          it 'has the corrent pagination meta data' do
            expect(response.parsed_body['meta']['pagination']).to eq(
              {
                'currentPage' => 1,
                'perPage' => 5,
                'totalPages' => 4,
                'totalEntries' => 17
              }
            )
          end
        end

        context 'when a middle page is requested' do
          let(:params) { { startDate: start_date, endDate: end_date, page: { number: 2, size: 5 }, useCache: true } }

          before { get '/mobile/v0/appointments', headers: iam_headers, params: params }

          it 'has 10 items' do
            expect(response.parsed_body['data'].size).to eq(5)
          end

          it 'has the correct links both prev and next' do
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=2&page[size]=5',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=1&page[size]=5',
                'prev' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=1&page[size]=5',
                'next' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=3&page[size]=5',
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=4&page[size]=5'
              }
            )
          end

          it 'has the correct pagination meta data' do
            expect(response.parsed_body['meta']['pagination']).to eq(
              {
                'currentPage' => 2,
                'perPage' => 5,
                'totalPages' => 4,
                'totalEntries' => 17
              }
            )
          end
        end

        context 'when the last page is requested' do
          let(:params) { { startDate: start_date, endDate: end_date, page: { number: 4, size: 5 }, useCache: true } }

          before { get '/mobile/v0/appointments', headers: iam_headers, params: params }

          it 'has 7 items' do
            expect(response.parsed_body['data'].size).to eq(2)
          end

          it 'has the correct links with no next' do
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=4&page[size]=5',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=1&page[size]=5',
                'prev' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=3&page[size]=5',
                'next' => nil,
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=4&page[size]=5'
              }
            )
          end

          it 'has the correct pagination meta data' do
            expect(response.parsed_body['meta']['pagination']).to eq(
              {
                'currentPage' => 4,
                'perPage' => 5,
                'totalPages' => 4,
                'totalEntries' => 17
              }
            )
          end
        end

        context 'when an out of bounds page is requested' do
          let(:params) do
            { startDate: start_date, endDate: end_date, page: { number: 99, size: 5 }, useCache: true }
          end

          before { get '/mobile/v0/appointments', headers: iam_headers, params: params }

          it 'returns a blank array' do
            expect(response.parsed_body['data']).to eq([])
          end

          it 'has the correct links with no next' do
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=99&page[size]=5',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=1&page[size]=5',
                'prev' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=4&page[size]=5',
                'next' => nil,
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-11-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[number]=4&page[size]=5'
              }
            )
          end
        end
      end
    end

    context 'with valid params' do
      let(:params) { { page: { number: 1, size: 10 }, useCache: true } }

      context 'with a user has mixed upcoming appointments' do
        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: iam_headers, params: params
              end
            end
          end
        end

        let(:first_appointment) { response.parsed_body['data'].first['attributes'] }
        let(:last_appointment) { response.parsed_body['data'].last['attributes'] }
        let(:cancelled_appointment) { response.parsed_body['data'][6]['attributes'] }
        let(:cc_appointment_with_blank_provider) { response.parsed_body['data'][1]['attributes'] }
        let(:cc_appointment_with_provider) { response.parsed_body['data'][2]['attributes'] }
        let(:covid_appointment) { response.parsed_body['data'][6]['attributes'] }

        it 'returns an ok response' do
          expect(response).to have_http_status(:ok)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('appointments')
        end

        it 'sorts the appointments by startDateUtc ascending' do
          expect(first_appointment['startDateUtc']).to be < last_appointment['startDateUtc']
        end

        it 'includes a status detail for cancelled appointments' do
          expect(cancelled_appointment['statusDetail']).to eq('CANCELLED BY PATIENT')
        end

        it 'returns nil for blank providers' do
          expect(cc_appointment_with_blank_provider['healthcareProvider']).to be_nil
        end

        it 'returns a joined name for non-blank providers' do
          expect(cc_appointment_with_provider['healthcareProvider']).to eq('Joseph Murphy')
        end

        it 'includes the expected properties for a VA appointment' do
          va_appointment = response.parsed_body['data'].filter { |a| a['attributes']['appointmentType'] == 'VA' }.first
          expect(va_appointment).to include(
            {
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'VA',
                'cancelId' => 'MzA4OzIwMjAxMTAzLjA5MDAwMDs0NDI7R3JlZW4gVGVhbSBDbGluaWMx',
                'comment' => nil,
                'healthcareProvider' => nil,
                'healthcareService' => 'Green Team Clinic1',
                'location' => {
                  'id' => '442',
                  'name' => 'Cheyenne VA Medical Center',
                  'address' => {
                    'street' => '2360 East Pershing Boulevard',
                    'city' => 'Cheyenne',
                    'state' => 'WY',
                    'zipCode' => '82001-5356'
                  },
                  'lat' => 41.148027,
                  'long' => -104.7862575,
                  'phone' => {
                    'areaCode' => '307',
                    'number' => '778-7550',
                    'extension' => nil
                  },
                  'url' => nil,
                  'code' => nil
                },
                'minutesDuration' => 20,
                'phoneOnly' => false,
                'startDateLocal' => '2020-11-03T09:00:00.000-07:00',
                'startDateUtc' => '2020-11-03T16:00:00.000+00:00',
                'status' => 'BOOKED',
                'statusDetail' => nil,
                'timeZone' => 'America/Denver',
                'vetextId' => '308;20201103.090000',
                'reason' => nil,
                'isCovidVaccine' => false
              }
            }
          )
        end

        it 'includes the expected properties for a CC appointment' do
          cc_appointment = response.parsed_body['data'].filter do |a|
            a['attributes']['appointmentType'] == 'COMMUNITY_CARE'
          end[5]

          expect(cc_appointment).to include(
            {
              'id' => '8a4885896a22f88f016a2c8834b1012d',
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'COMMUNITY_CARE',
                'cancelId' => nil,
                'comment' => 'Please arrive 15 minutes ahead of appointment.',
                'healthcareProvider' => nil,
                'healthcareService' => 'Atlantic Medical Care',
                'location' => {
                  'id' => nil,
                  'name' => 'Atlantic Medical Care',
                  'address' => {
                    'street' => '123 Main Street',
                    'city' => 'Orlando',
                    'state' => 'FL',
                    'zipCode' => '32826'
                  },
                  'lat' => nil,
                  'long' => nil,
                  'phone' => {
                    'areaCode' => '407',
                    'number' => '555-1212',
                    'extension' => nil
                  },
                  'url' => nil,
                  'code' => nil
                },
                'minutesDuration' => 60,
                'phoneOnly' => false,
                'startDateLocal' => '2020-11-25T19:30:00.000-05:00',
                'startDateUtc' => '2020-11-26T00:30:00.000Z',
                'status' => 'BOOKED',
                'statusDetail' => nil,
                'timeZone' => 'America/New_York',
                'vetextId' => nil,
                'reason' => nil,
                'isCovidVaccine' => false
              }
            }
          )
        end

        it 'includes isCovidVaccine: true for covid appointments' do
          expect(covid_appointment['isCovidVaccine']).to eq(true)
        end
      end

      context 'with a user has mixed upcoming appointments and requests a date range outside +/-1 year' do
        let(:end_date) { (Time.now.utc + 2.years).iso8601 }
        let(:first_appointment) { response.parsed_body['data'].first['attributes'] }
        let(:last_appointment) { response.parsed_body['data'].last['attributes'] }
        let(:params) { { endDate: end_date, page: { number: 1, size: 10 }, useCache: true } }

        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_large_range', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_large_range', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: iam_headers, params: params
              end
            end
          end
        end

        it 'returns an ok response' do
          expect(response).to have_http_status(:ok)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('appointments')
        end

        it 'sorts the appointments by startDateUtc ascending' do
          expect(first_appointment['startDateUtc']).to be < last_appointment['startDateUtc']
        end

        it 'includes the expected properties for a VA appointment' do
          va_appointment = response.parsed_body['data'].filter { |a| a['attributes']['appointmentType'] == 'VA' }.first
          expect(va_appointment).to include(
            {
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'VA',
                'cancelId' => 'MzA4OzIwMjAxMTAzLjA5MDAwMDs0NDI7R3JlZW4gVGVhbSBDbGluaWMx',
                'comment' => nil,
                'healthcareProvider' => nil,
                'healthcareService' => 'Green Team Clinic1',
                'location' => {
                  'id' => '442',
                  'name' => 'Cheyenne VA Medical Center',
                  'address' => {
                    'street' => '2360 East Pershing Boulevard',
                    'city' => 'Cheyenne',
                    'state' => 'WY',
                    'zipCode' => '82001-5356'
                  },
                  'lat' => 41.148027,
                  'long' => -104.7862575,
                  'phone' => {
                    'areaCode' => '307',
                    'number' => '778-7550',
                    'extension' => nil
                  },
                  'url' => nil,
                  'code' => nil
                },
                'minutesDuration' => 20,
                'phoneOnly' => false,
                'startDateLocal' => '2020-11-03T09:00:00.000-07:00',
                'startDateUtc' => '2020-11-03T16:00:00.000+00:00',
                'status' => 'BOOKED',
                'statusDetail' => nil,
                'timeZone' => 'America/Denver',
                'vetextId' => '308;20201103.090000',
                'reason' => nil,
                'isCovidVaccine' => false
              }
            }
          )
        end

        it 'includes the expected properties for a CC appointment' do
          cc_appointment = response.parsed_body['data'].filter do |a|
            a['attributes']['appointmentType'] == 'COMMUNITY_CARE'
          end[5]

          expect(cc_appointment).to include(
            {
              'id' => '8a4885896a22f88f016a2c8834b1012d',
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'COMMUNITY_CARE',
                'cancelId' => nil,
                'comment' => 'Please arrive 15 minutes ahead of appointment.',
                'healthcareProvider' => nil,
                'healthcareService' => 'Atlantic Medical Care',
                'location' => {
                  'id' => nil,
                  'name' => 'Atlantic Medical Care',
                  'address' => {
                    'street' => '123 Main Street',
                    'city' => 'Orlando',
                    'state' => 'FL',
                    'zipCode' => '32826'
                  },
                  'lat' => nil,
                  'long' => nil,
                  'phone' => {
                    'areaCode' => '407',
                    'number' => '555-1212',
                    'extension' => nil
                  },
                  'url' => nil,
                  'code' => nil
                },
                'minutesDuration' => 60,
                'phoneOnly' => false,
                'startDateLocal' => '2020-11-25T19:30:00.000-05:00',
                'startDateUtc' => '2020-11-26T00:30:00.000Z',
                'status' => 'BOOKED',
                'statusDetail' => nil,
                'timeZone' => 'America/New_York',
                'vetextId' => nil,
                'reason' => nil,
                'isCovidVaccine' => false
              }
            }
          )
        end
      end

      context 'when va appointments succeeds but cc appointments fail' do
        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: iam_headers, params: params
              end
            end
          end
        end

        it 'returns a 502 response' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('errors')
        end
      end

      context 'when cc appointments succeeds but va appointments fail' do
        before do
          VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_500', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end

        it 'returns a 502 response' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('errors')
        end
      end

      context 'when both fail' do
        before do
          VCR.use_cassette('appointments/get_appointments_500', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end

        it 'returns a 502 response' do
          expect(response).to have_http_status(:bad_gateway)
        end
      end

      context 'when the VA endpoint returns a partial response with an error' do
        before do
          VCR.use_cassette('appointments/get_appointments_200_with_error', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end

        it 'returns a 502 response' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when a VA appointment should use the clinic rather than facility address' do
      before do
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))

        VCR.use_cassette('appointments/get_facilities_address_bug', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_address_bug', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_address_bug', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: nil
            end
          end
        end
      end

      after { Timecop.return }

      let(:facility_appointment) { response.parsed_body['data'][5]['attributes'] }
      let(:clinic_appointment) { response.parsed_body['data'][6]['attributes'] }

      it 'has clinic appointments use the clinic address' do
        expect(clinic_appointment['location']).to eq(
          {
            'id' => '442',
            'name' => 'Fort Collins VA Clinic',
            'address' => {
              'street' => '2509 Research Boulevard',
              'city' => 'Fort Collins',
              'state' => 'CO',
              'zipCode' => '80526-8108'
            },
            'lat' => 40.553874,
            'long' => -105.087951,
            'phone' => {
              'areaCode' => '970',
              'number' => '224-1550',
              'extension' => nil
            },
            'url' => nil,
            'code' => nil
          }
        )
      end

      it 'has facility appointments use the facility address' do
        expect(facility_appointment['location']).to eq(
          {
            'id' => '442',
            'name' => 'Cheyenne VA Medical Center',
            'address' => {
              'street' => '2360 East Pershing Boulevard',
              'city' => 'Cheyenne',
              'state' => 'WY',
              'zipCode' => '82001-5356'
            },
            'lat' => 41.148027,
            'long' => -104.7862575,
            'phone' => {
              'areaCode' => '307',
              'number' => '778-7550',
              'extension' => nil
            },
            'url' => nil,
            'code' => nil
          }
        )
      end
    end

    context "when a VA appointment's facility does not have a phone number" do
      before do
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))

        VCR.use_cassette('appointments/get_facilities_phone_bug', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_address_bug', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_address_bug', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: nil
            end
          end
        end
      end

      after { Timecop.return }

      let(:location) { response.parsed_body['data'].first.dig('attributes', 'location') }

      it 'correctly parses the phone number as nil' do
        expect(location).to eq(
          {
            'id' => '442',
            'name' => 'Cheyenne VA Medical Center',
            'address' => {
              'street' => '2360 East Pershing Boulevard',
              'city' => 'Cheyenne',
              'state' => 'WY',
              'zipCode' => '82001-5356'
            },
            'lat' => 41.148027,
            'long' => -104.7862575,
            'phone' => nil,
            'url' => nil,
            'code' => nil
          }
        )
      end
    end

    context "when a VA appointment's facility phone number is malformed" do
      before do
        allow(Rails.logger).to receive(:warn)
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))

        VCR.use_cassette('appointments/get_facilities_phone_bug', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_address_bug', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_address_bug', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: nil
            end
          end
        end
      end

      after { Timecop.return }

      let(:location) { response.parsed_body['data'][1].dig('attributes', 'location') }

      it 'correctly parses the phone number as nil' do
        expect(location).to eq(
          {
            'id' => '442',
            'name' => 'Cheyenne VA Medical Center',
            'address' => {
              'street' => '2360 East Pershing Boulevard',
              'city' => 'Cheyenne',
              'state' => 'WY',
              'zipCode' => '82001-5356'
            },
            'lat' => 41.148027,
            'long' => -104.7862575,
            'phone' => nil,
            'url' => nil,
            'code' => nil
          }
        )
      end

      it 'logs the facility phone number' do
        expect(Rails.logger).to have_received(:warn).at_least(:once).with(
          'mobile appointments failed to parse facility phone number',
          {
            facility_id: 'vha_442GC',
            facility_phone: {
              'fax' => '970-407-7440',
              'main' => '970224-1550',
              'pharmacy' => '866-420-6337',
              'afterHours' => '307-778-7550',
              'patientAdvocate' => '307-778-7550 x7517',
              'mentalHealthClinic' => '307-778-7349',
              'enrollmentCoordinator' => '307-778-7550 x7579'
            }
          }
        )
      end
    end

    describe 'sorting' do
      before do
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))

        VCR.use_cassette('appointments/get_facilities_address_bug', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_address_bug', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_address_bug', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end
      end

      after { Timecop.return }

      let(:first_appointment_date) { DateTime.parse(response.parsed_body['data'].first['attributes']['startDateUtc']) }
      let(:last_appointment_date) { DateTime.parse(response.parsed_body['data'].last['attributes']['startDateUtc']) }

      context 'when ascending sorting is requested in params' do
        let(:params) { { sort: 'startDateUtc' } }

        it 'has the most recent appointments come first' do
          expect(first_appointment_date).to be < last_appointment_date
        end
      end

      context 'when reverse sorting is requested in params' do
        let(:params) { { sort: '-startDateUtc' } }

        it 'has the earlier appointments come first' do
          expect(first_appointment_date).to be > last_appointment_date
        end
      end

      context 'when no sorting is requested in params' do
        let(:params) { nil }

        it 'defaults to having the most recent appointments come first' do
          expect(first_appointment_date).to be < last_appointment_date
        end
      end
    end

    describe 'phone only' do
      before do
        Timecop.freeze(Time.zone.parse('2021-09-13T11:07:07Z'))

        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_phone_only', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_phone_only', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end
      end

      after { Timecop.return }

      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 1.year).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date } }
      let(:appointment_with_phone) { response.parsed_body['data'][0]['attributes'] }
      let(:appointment_without_phone) { response.parsed_body['data'][1]['attributes'] }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('appointments')
      end

      context 'with a phone appointment' do
        it 'has a phoneOnly flag of true' do
          expect(appointment_with_phone['phoneOnly']).to be_truthy
        end
      end

      context 'with a non phone appointment' do
        it 'has a phoneOnly flag of false' do
          expect(appointment_without_phone['phoneOnly']).to be_falsey
        end
      end
    end

    describe 'reason for visit' do
      before do
        Timecop.freeze(Time.zone.parse('2021-09-13T11:07:07Z'))

        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_reason_for_visit', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_reason_for_visit', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end
      end

      after { Timecop.return }

      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 1.year).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date } }
      let(:va_appointment_with_reason) { response.parsed_body['data'][0]['attributes'] }
      let(:va_appointment_without_reason) { response.parsed_body['data'][2]['attributes'] }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('appointments')
      end

      context 'va appointments' do
        it 'contains reason' do
          expect(va_appointment_with_reason['reason']).to eq('Follow-up/Routine: Reason 1')
        end

        it 'reason does not exist' do
          expect(va_appointment_without_reason['reason']).to be_nil
        end
      end
    end
  end
end
