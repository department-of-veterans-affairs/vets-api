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
      before do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: nil
            end
          end
        end
      end

      it 'defaults to a range of -3 months and + 6 months' do
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

    context 'with valid params' do
      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date, useCache: true } }

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
                'cancelId' => 'MjAyMDExMDMwOTAwMDA=-MzA4-NDQy-Q0hZIFBDIEtJTFBBVFJJQ0s=',
                'comment' => nil,
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
                'cancelId' => nil,
                'comment' => 'Test',
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

      context 'with the cached flag set to false' do
        let(:start_date) { Time.now.utc.iso8601 }
        let(:end_date) { (Time.now.utc + 3.months).iso8601 }
        let(:params) { { startDate: start_date, endDate: end_date, useCache: false } }

        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_cache_false', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_cache_false', match_requests_on: %i[method uri]) do
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
      end

      context 'with no cached flag (defaults to false)' do
        let(:start_date) { Time.now.utc.iso8601 }
        let(:end_date) { (Time.now.utc + 3.months).iso8601 }
        let(:params) { { startDate: start_date, endDate: end_date } }

        before do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_cache_false', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_cache_false', match_requests_on: %i[method uri]) do
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

      context 'when there are cached appointments' do
        let(:user) { FactoryBot.build(:iam_user) }
        let(:params) { { useCache: true } }

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
          options = { meta: { errors: nil } }
          json = Mobile::V0::AppointmentSerializer.new(appointments, options).serialized_json

          Mobile::V0::Appointment.set_cached_appointments(user, json)
        end

        after { Timecop.return }

        it 'retrieves the cached appointments rather than hitting the service' do
          expect_any_instance_of(Mobile::V0::Appointments::Proxy).not_to receive(:get_appointments)
          get '/mobile/v0/appointments', headers: iam_headers, params: params
          expect(response).to have_http_status(:ok)
        end

        it 'clears the cache' do
          get '/mobile/v0/appointments', headers: iam_headers, params: params
          expect(Mobile::V0::Appointment.get_cached_appointments(user)).to be_nil
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'PUT /mobile/v0/appointments/cancel' do
    context 'when request body params are missing' do
      let(:cancel_id) do
        'abc123'
      end

      it 'returns a 422 that lists all validation errors' do
        VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
          put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('errors')
          expect(response.parsed_body['errors'].size).to eq(1)
        end
      end
    end

    context 'with valid params' do
      let(:cancel_id) do
        Mobile::V0::Contracts::CancelAppointment.encode_cancel_id(
          start_date_local: DateTime.parse('2019-11-15T13:00:00'),
          clinic_id: '437',
          facility_id: '983',
          healthcare_service: 'CHY VISUAL FIELD'
        )
      end

      context 'when a valid cancel reason is not returned in the list' do
        it 'returns bad request with detail in errors' do
          VCR.use_cassette('appointments/get_cancel_reasons_invalid', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body['errors'].first['detail']).to eq(
              'This appointment can not be cancelled online because a prerequisite cancel reason could not be found'
            )
          end
        end
      end

      context 'when cancel reason returns a 500' do
        it 'returns bad request with detail in errors' do
          VCR.use_cassette('appointments/get_cancel_reasons_500', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

            expect(response).to have_http_status(:bad_gateway)
            expect(response.parsed_body['errors'].first['detail'])
              .to eq('Received an an invalid response from the upstream server')
          end
        end
      end

      context 'when a appointment cannot be cancelled online' do
        it 'returns bad request with detail in errors' do
          VCR.use_cassette('appointments/put_cancel_appointment_409', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

              expect(response).to have_http_status(:conflict)
              expect(response.parsed_body['errors'].first['detail'])
                .to eq('The facility does not support online scheduling or cancellation of appointments')
            end
          end
        end
      end
    end

    context 'when appointment can be cancelled' do
      let(:cancel_id) do
        Mobile::V0::Contracts::CancelAppointment.encode_cancel_id(
          start_date_local: DateTime.parse('2019-11-15T13:00:00'),
          clinic_id: '437',
          facility_id: '983',
          healthcare_service: 'CHY VISUAL FIELD'
        )
      end

      it 'cancels the appointment' do
        VCR.use_cassette('appointments/put_cancel_appointment', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

            expect(response).to have_http_status(:success)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end

      context 'when appointment can be cancelled but fails' do
        let(:cancel_id) do
          Mobile::V0::Contracts::CancelAppointment.encode_cancel_id(
            start_date_local: DateTime.parse('2019-11-20T17:00:00'),
            clinic_id: '437',
            facility_id: '983',
            healthcare_service: 'CHY VISUAL FIELD'
          )
        end

        it 'raises a 502' do
          VCR.use_cassette('appointments/put_cancel_appointment_500', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

              expect(response).to have_http_status(:bad_gateway)
              expect(response.body).to match_json_schema('errors')
            end
          end
        end
      end
    end
  end
end
