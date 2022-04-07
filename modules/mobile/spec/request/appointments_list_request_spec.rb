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
    Flipper.disable(:mobile_appointment_requests)
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

    describe 'start and end date' do
      let(:beginning_of_last_year) { (DateTime.now.utc.beginning_of_year - 1.year) }
      let(:one_year_from_now) { (DateTime.now.utc.beginning_of_day + 1.year) }

      context 'when omitted from query params' do
        let(:params) { { page: { number: 1, size: 10 }, useCache: false } }

        it 'defaults to beginning of the previous year to one year from now' do
          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_va_appointments).with(
            beginning_of_last_year, one_year_from_now
          )
          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_cc_appointments).with(
            beginning_of_last_year, one_year_from_now
          )

          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
      end

      context 'when provided start date is after beginning of the previous year' do
        let(:start_date) { (DateTime.now.utc.beginning_of_year - 1.year + 1.day) }
        let(:params) { { startDate: start_date.iso8601 } }

        it 'defaults to the beginning of the the previous year' do
          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_va_appointments).with(
            beginning_of_last_year, one_year_from_now
          )

          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_cc_appointments).with(
            beginning_of_last_year, one_year_from_now
          )

          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
      end

      context 'when provided start date is before the beginning of the previous year' do
        let(:start_date) { (DateTime.now.utc.beginning_of_year - 1.year - 1.day) }
        let(:params) { { startDate: start_date.iso8601 } }

        it 'uses the provided start date' do
          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_va_appointments).with(
            start_date, one_year_from_now
          )

          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_cc_appointments).with(
            start_date, one_year_from_now
          )

          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
      end

      context 'when provided end date is before one year from now' do
        let(:end_date) { (DateTime.now.utc.beginning_of_day + 1.year - 1.day) }
        let(:params) { { endDate: end_date.iso8601 } }

        it 'defaults to one year from now' do
          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_va_appointments).with(
            beginning_of_last_year, one_year_from_now
          )

          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_cc_appointments).with(
            beginning_of_last_year, one_year_from_now
          )

          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
      end

      context 'when provided end date is after one year from now' do
        let(:end_date) { (DateTime.now.utc.beginning_of_day + 1.year + 1.day) }
        let(:params) { { endDate: end_date.iso8601 } }

        it 'uses the provided end date' do
          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_va_appointments).with(
            beginning_of_last_year, end_date
          )

          expect_any_instance_of(Mobile::V0::Appointments::Service).to receive(:fetch_cc_appointments).with(
            beginning_of_last_year, end_date
          )

          get '/mobile/v0/appointments', headers: iam_headers, params: params
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
    end

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

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
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
      va_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments.json')
      cc_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'cc_appointments.json')
      va_json = File.read(va_path)
      cc_json = File.read(cc_path)
      va_appointments = Mobile::V0::Adapters::VAAppointments.new.parse(
        JSON.parse(va_json, symbolize_names: true)
      )
      cc_appointments = Mobile::V0::Adapters::CommunityCareAppointments.new.parse(
        JSON.parse(cc_json, symbolize_names: true)
      )

      appointments = (va_appointments + cc_appointments).sort_by(&:start_date_utc)

      let(:start_date) { (Time.now.utc.beginning_of_year - 1.year).iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date, page: { number: 1, size: 30 }, useCache: true } }
      let(:user) { build(:iam_user) }
      let(:total_appointments_within_range) do
        appointments.filter { |p| p.start_date_utc.iso8601 >= start_date && p.start_date_utc.iso8601 <= end_date }.count
      end
      let(:total_appointments_outside_range) { appointments.count - total_appointments_within_range }
      let(:request_appointments) { get '/mobile/v0/appointments', headers: iam_headers, params: params }

      before do
        Mobile::V0::Appointment.set_cached(user, appointments)
      end

      after { Timecop.return }

      it 'retrieves the cached appointments rather than hitting the service' do
        expect_any_instance_of(VAOS::AppointmentService).not_to receive(:get_appointments)
        request_appointments
        expect(response).to have_http_status(:ok)
      end

      it 'retrieves the cached appointments only within date range' do
        request_appointments
        expect(response.parsed_body['data'].size).to eq(total_appointments_within_range)
        expect(total_appointments_outside_range).to eq(2)
      end

      describe 'pagination' do
        context 'when the first page is requested' do
          let(:params) { { startDate: start_date, endDate: end_date, page: { number: 1, size: 5 }, useCache: true } }

          before { get '/mobile/v0/appointments', headers: iam_headers, params: params }

          it 'has 5 items' do
            expect(response.parsed_body['data'].size).to eq(5)
          end

          it 'has the correct links with no prev' do
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=1',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=1',
                'prev' => nil,
                'next' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=2',
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=5'
              }
            )
          end

          it 'has the corrent pagination meta data' do
            expect(response.parsed_body['meta']['pagination']).to eq(
              {
                'currentPage' => 1,
                'perPage' => 5,
                'totalPages' => 5,
                'totalEntries' => total_appointments_within_range
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
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=2',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=1',
                'prev' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=1',
                'next' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=3',
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=5'
              }
            )
          end

          it 'has the correct pagination meta data' do
            expect(response.parsed_body['meta']['pagination']).to eq(
              {
                'currentPage' => 2,
                'perPage' => 5,
                'totalPages' => 5,
                'totalEntries' => total_appointments_within_range
              }
            )
          end
        end

        context 'when the last page is requested' do
          let(:params) { { startDate: start_date, endDate: end_date, page: { number: 5, size: 5 }, useCache: true } }

          before { get '/mobile/v0/appointments', headers: iam_headers, params: params }

          it 'has 5 items' do
            expect(response.parsed_body['data'].size).to eq(5)
          end

          it 'has the correct links with no next' do
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=5',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=1',
                'prev' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=4',
                'next' => nil,
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=5'
              }
            )
          end

          it 'has the correct pagination meta data' do
            expect(response.parsed_body['meta']['pagination']).to eq(
              {
                'currentPage' => 5,
                'perPage' => 5,
                'totalPages' => 5,
                'totalEntries' => total_appointments_within_range
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
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=99',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=1',
                'prev' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=5',
                'next' => nil,
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2019-01-01T00:00:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=5&page[number]=5'
              }
            )
          end
        end
      end
    end

    context 'with at home video appointment with no location' do
      before do
        VCR.use_cassette('appointments/get_cc_appointments_empty', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_appointments_at_home_no_location', match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params: nil
          end
        end
      end

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end

      it 'defaults location data' do
        appointment = response.parsed_body.dig('data', 0, 'attributes')

        expect(appointment['appointmentType']).to eq('VA_VIDEO_CONNECT_HOME')
        expect(appointment['location']).to eq({ 'id' => nil,
                                                'name' => 'No location provided',
                                                'address' => { 'street' => nil, 'city' => nil, 'state' => nil,
                                                               'zipCode' => nil },
                                                'lat' => nil,
                                                'long' => nil,
                                                'phone' => nil,
                                                'url' => 'https://care2.evn.va.gov',
                                                'code' => '5364921#' })
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
                'isCovidVaccine' => false,
                'isPending' => false,
                'proposedTimes' => nil,
                'typeOfCare' => nil,
                'patientPhoneNumber' => nil,
                'patientEmail' => nil,
                'bestTimeToCall' => nil,
                'friendlyLocationName' => nil

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
                'isCovidVaccine' => false,
                'isPending' => false,
                'proposedTimes' => nil,
                'typeOfCare' => nil,
                'patientPhoneNumber' => nil,
                'patientEmail' => nil,
                'bestTimeToCall' => nil,
                'friendlyLocationName' => nil
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
                'isCovidVaccine' => false,
                'isPending' => false,
                'proposedTimes' => nil,
                'typeOfCare' => nil,
                'patientPhoneNumber' => nil,
                'patientEmail' => nil,
                'bestTimeToCall' => nil,
                'friendlyLocationName' => nil
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
                'isCovidVaccine' => false,
                'isPending' => false,
                'proposedTimes' => nil,
                'typeOfCare' => nil,
                'patientPhoneNumber' => nil,
                'patientEmail' => nil,
                'bestTimeToCall' => nil,
                'friendlyLocationName' => nil
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

    context 'when no va appointments are returned' do
      before do
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
      end

      after { Timecop.return }

      it 'returns 200' do
        VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_appointments_empty', match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: iam_headers, params: nil

            expect(response.status).to eq 200
          end
        end
      end
    end

    context 'when no cc appointments are returned' do
      before do
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
      end

      after { Timecop.return }

      it 'returns 200' do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_empty', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: nil

              expect(response.status).to eq 200
            end
          end
        end
      end
    end

    describe 'pending appointments' do
      let(:start_date) { (Time.now.utc - 3.months).iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:submitted_va_appt_request_id) { '8a48e8db6d70a38a016d72b354240002' }
      let(:cancelled_cc_appt_request_id) { '8a48912a6d02b0fc016d20b4ccb9001a' }
      let(:booked_request_id) { '8a48dea06c84a667016c866de87c000b' }
      let(:resolved_request_id) { '8a48e8db6d7682c3016d88dc21650024' }
      let(:get_appointments) do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointment_requests', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: iam_headers, params: params
              end
            end
          end
        end
      end

      context 'with feature flag off' do
        let(:params) do
          {
            include: ['pending'],
            page: { number: 1, size: 100 },
            startDate: start_date,
            endDate: end_date
          }
        end

        it 'does not return appointment requests' do
          Flipper.disable(:mobile_appointment_requests)

          get_appointments

          pending = response.parsed_body['data'].select do |appt|
            appt['attributes']['isPending'] == true
          end
          expect(pending).to be_empty
        end
      end

      context 'with feature flag on' do
        before { Flipper.enable(:mobile_appointment_requests) }

        context 'when pending appointments are not included in the query params' do
          let(:params) do
            {
              page: { number: 1, size: 100 },
              startDate: start_date,
              endDate: end_date
            }
          end

          it 'does not include pending appointments' do
            get_appointments

            pending = response.parsed_body['data'].select do |appt|
              appt['attributes']['isPending'] == true
            end
            expect(pending).to be_empty
          end
        end

        context 'when pending appointments are included in the query params' do
          let(:params) do
            {
              include: ['pending'],
              page: { number: 1, size: 100 },
              startDate: start_date,
              endDate: end_date
            }
          end

          it 'returns cancelled and submitted requests in the date range and omits other statuses' do
            get_appointments

            pending = response.parsed_body['data'].select do |appt|
              appt['attributes']['isPending'] == true
            end
            requested = pending.pluck('id')
            expect(requested).to include(submitted_va_appt_request_id, cancelled_cc_appt_request_id)
            expect(requested).not_to include(booked_request_id, resolved_request_id)
          end

          it 'includes cc data for cc appointments' do
            expected_response = {
              'id' => '8a48912a6d02b0fc016d20b4ccb9001a',
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'COMMUNITY_CARE',
                'cancelId' => '8a48912a6d02b0fc016d20b4ccb9001a',
                'comment' => nil,
                'healthcareProvider' => 'Vilasini Reddy',
                'healthcareService' => 'Test clinic 2',
                'location' => {
                  'id' => nil,
                  'name' => 'Test clinic 2',
                  'address' => {
                    'street' => '123 Sesame St.',
                    'city' => 'Cheyenne',
                    'state' => 'VA',
                    'zipCode' => '20171'
                  },
                  'lat' => nil,
                  'long' => nil,
                  'phone' => nil,
                  'url' => nil,
                  'code' => nil
                },
                'minutesDuration' => nil,
                'phoneOnly' => false,
                'startDateLocal' => '2020-10-01T06:00:00.000-06:00',
                'startDateUtc' => '2020-10-01T12:00:00.000Z',
                'status' => 'CANCELLED',
                'statusDetail' => 'CANCELLED BY CLINIC',
                'timeZone' => 'America/Denver',
                'vetextId' => nil,
                'reason' => 'routine-follow-up',
                'isCovidVaccine' => nil,
                'isPending' => true,
                'proposedTimes' => [
                  {
                    'date' => '10/01/2020',
                    'time' => 'PM'
                  },
                  {
                    'date' => '10/02/2020',
                    'time' => 'PM'
                  },
                  {
                    'date' => nil,
                    'time' => nil
                  }
                ],
                'typeOfCare' => 'Optometry (routine eye exam)',
                'patientPhoneNumber' => '(703) 652-0000',
                'patientEmail' => 'samatha.girla@va.gov',
                'bestTimeToCall' => %w[Afternoon Evening Morning],
                'friendlyLocationName' => 'CHYSHR-Cheyenne VA Medical Center'
              }
            }

            get_appointments

            requested = response.parsed_body['data'].find { |appts| appts['id'] == cancelled_cc_appt_request_id }
            expect(requested).to eq(expected_response)
          end

          it 'includes va data for va appointments' do
            expected_response = {
              'id' => '8a48e8db6d70a38a016d72b354240002',
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'VA',
                'cancelId' => '8a48e8db6d70a38a016d72b354240002',
                'comment' => nil,
                'healthcareProvider' => nil,
                'healthcareService' => nil,
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
                'minutesDuration' => nil,
                'phoneOnly' => false,
                'startDateLocal' => '2020-11-02T01:00:00.000-07:00',
                'startDateUtc' => '2020-11-02T08:00:00.000Z',
                'status' => 'SUBMITTED',
                'statusDetail' => nil,
                'timeZone' => 'America/Denver',
                'vetextId' => nil,
                'reason' => 'New Issue',
                'isCovidVaccine' => nil,
                'isPending' => true,
                'proposedTimes' => [
                  {
                    'date' => '10/01/2020',
                    'time' => 'PM'
                  },
                  {
                    'date' => '11/03/2020',
                    'time' => 'AM'
                  },
                  {
                    'date' => '11/02/2020',
                    'time' => 'AM'
                  }
                ],
                'typeOfCare' => 'Primary Care',
                'patientPhoneNumber' => '(666) 666-6666',
                'patientEmail' => 'Vilasini.reddy@va.gov',
                'bestTimeToCall' => ['Morning'],
                'friendlyLocationName' => 'DAYTSHR -Dayton VA Medical Center'
              }
            }

            get_appointments

            requested = response.parsed_body['data'].find { |appts| appts['id'] == submitted_va_appt_request_id }
            expect(requested).to eq(expected_response)
          end

          it 'orders appointments by first proposed time' do
            get_appointments

            order_times = response.parsed_body['data'].collect do |a|
              a.dig('attributes', 'startDateUtc')
            end

            # appointment request has one other proposed time, but this is the chronologically first in the future
            first_proposed_time_in_future = '2020-11-02T08:00:00.000Z'
            # request has one other proposed time, but both are past, so it selects the first chronologically
            first_proposed_time_in_past = '2020-10-01T12:00:00.000Z'

            expect(order_times).to include(first_proposed_time_in_future, first_proposed_time_in_past)
            sorted = order_times.map(&:to_datetime).sort { |a, b| a <=> b }
            expect(order_times.map(&:to_datetime)).to eq(sorted)
          end

          it 'forms navigation links with query params' do
            get_appointments
            expect(response.parsed_body['links']).to eq(
              {
                'self' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-08-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=100&page[number]=1&include[]=pending',
                'first' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-08-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=100&page[number]=1&include[]=pending',
                'prev' => nil,
                'next' => nil,
                'last' => 'http://www.example.com/mobile/v0/appointments?startDate=2020-08-01T10:30:00+00:00&endDate=2021-02-01T10:30:00+00:00&useCache=true&page[size]=100&page[number]=1&include[]=pending'
              }
            )
          end

          context 'if the param is named included' do
            let(:params) do
              {
                included: ['pending'],
                page: { number: 1, size: 100 },
                startDate: start_date,
                endDate: end_date
              }
            end

            before { get_appointments }

            it 'returns a 200' do
              expect(response).to have_http_status(:ok)
            end

            it 'still returns pending appointments' do
              expect(response.parsed_body['data'].first['attributes']).to include({ 'isPending' => true })
            end
          end
        end

        context 'when the appointments request service fails' do
          let(:params) do
            {
              include: ['pending'],
              page: { number: 1, size: 100 },
              startDate: start_date,
              endDate: end_date
            }
          end

          it 'returns 502' do
            VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
                VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
                  VCR.use_cassette('appointments/get_appointment_requests_500',
                                   match_requests_on: %i[method uri]) do
                    get '/mobile/v0/appointments', headers: iam_headers, params: params
                  end
                end
              end
            end

            expect(response.status).to eq(502)
          end
        end
      end
    end
  end
end
