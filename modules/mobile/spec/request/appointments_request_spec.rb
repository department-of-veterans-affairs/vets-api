# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointments', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in
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
      it 'returns a bad request error' do
        get '/mobile/v0/appointments', headers: iam_headers, params: nil

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          {
            'errors' => [
              {
                'title' => 'Invalid field value',
                'detail' => '"" is not a valid value for "startDate"',
                'code' => '103',
                'status' => '400'
              }
            ]
          }
        )
      end
    end

    context 'with an invalid date in params' do
      let(:start_date) { 42 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date } }

      it 'returns a bad request error' do
        get '/mobile/v0/appointments', headers: iam_headers, params: params

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          {
            'errors' => [
              {
                'title' => 'Invalid field value',
                'detail' => '"42" is not a valid value for "startDate"',
                'code' => '103',
                'status' => '400'
              }
            ]
          }
        )
      end
    end

    context 'with valid params' do
      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date } }

      context 'with a user has mixed upcoming appointments' do
        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: iam_headers, params: params
              end
            end
          end
        end

        let(:first_appointment) { response.parsed_body['data'].first['attributes'] }
        let(:last_appointment) { response.parsed_body['data'].last['attributes'] }

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
                'comment' => nil,
                'clinicId' => '308',
                'facilityId' => '442',
                'healthcareService' => 'CHY PC KILPATRICK',
                'location' => {
                  'name' => 'CHEYENNE VAMC',
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
                'startDateLocal' => '2020-11-03T09:00:00.000-07:00',
                'startDateUtc' => '2020-11-03T16:00:00.000+00:00',
                'status' => 'BOOKED',
                'timeZone' => 'America/Denver'
              }
            }
          )
        end

        it 'includes the expected properties for a CC appointment' do
          cc_appointment = response.parsed_body['data'].filter do |a|
            a['attributes']['appointmentType'] == 'COMMUNITY_CARE'
          end.first

          expect(cc_appointment).to include(
            {
              'id' => '8a48912a6c2409b9016c4e4ef7ae018b',
              'type' => 'appointment',
              'attributes' => {
                'appointmentType' => 'COMMUNITY_CARE',
                'comment' => 'Test',
                'clinicId' => nil,
                'facilityId' => nil,
                'healthcareService' => 'rtt',
                'location' => {
                  'name' => 'rtt',
                  'address' => {
                    'street' => 'test drive',
                    'city' => 'clraksburg',
                    'state' => 'MD',
                    'zipCode' => '00000'
                  },
                  'lat' => nil,
                  'long' => nil,
                  'phone' => {
                    'areaCode' => '301',
                    'number' => '916-1212',
                    'extension' => nil
                  },
                  'url' => nil,
                  'code' => nil
                },
                'minutesDuration' => 60,
                'startDateLocal' => '2020-11-01T22:30:00.000-05:00',
                'startDateUtc' => '2020-11-02T03:30:00.000Z',
                'status' => 'BOOKED',
                'timeZone' => 'America/New_York'
              }
            }
          )
        end
      end

      context 'when va appointments succeeds but cc appointments fail' do
        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: iam_headers, params: params
              end
            end
          end
        end

        it 'returns an ok response' do
          expect(response).to have_http_status(:ok)
        end

        it 'has va appointments' do
          expect(response.parsed_body['data'].size).to eq(8)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('appointments')
        end
      end

      context 'when cc appointments succeeds but va appointments fail' do
        before do
          VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_500', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end

        it 'returns an ok response' do
          expect(response).to have_http_status(:ok)
        end

        it 'has va appointments' do
          expect(response.parsed_body['data'].size).to eq(33)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('appointments')
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
            VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end

        it 'returns a 200 response' do
          expect(response).to have_http_status(:ok)
        end

        it 'has the right CC count' do
          expect(response.parsed_body['data'].size).to eq(33)
        end
      end
    end
  end
end
