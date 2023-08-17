# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'facilities info', type: :request do
  include JsonSchemaMatchers

  let(:params) { { lat: 40.5, long: 100.1 } }
  let(:user) { FactoryBot.build(:iam_user, :custom_facility_ids, facility_ids: %w[757 358 999]) }
  let(:facilities) { response.parsed_body.dig('data', 'attributes', 'facilities') }
  # used for pre-loading appointments into redis
  let(:appointments) do
    va_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures',
                              'VAOS_v2_appointments_facilities.json')
    va_json = File.read(va_path)
    va_appointments = Mobile::V0::Adapters::VAOSV2Appointments.new.parse(
      JSON.parse(va_json, symbolize_names: true)
    )

    va_appointments.sort_by(&:start_date_utc)
  end

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Settings.mhv).to receive(:facility_range).and_return([[358, 718], [720, 758], [983, 984], [999, 999]])
  end

  describe 'GET /mobile/v0/facilities-info' do
    it 'returns a list of the user\'s va facilities' do
      VCR.use_cassette('mobile/appointments/get_multiple_facilities_without_children_200',
                       match_requests_on: %i[method uri]) do
        get('/mobile/v0/facilities-info', headers: iam_headers)
        facility_ids = facilities.pluck('id')
        expect(response).to have_http_status(:ok)
        expect(user.va_treatment_facility_ids).to match_array(facility_ids)
        expect(response.body).to match_json_schema('facilities_info')
      end
    end
  end

  describe 'GET /mobile/v0/facilities-info/:sort' do
    describe 'sort method' do
      context 'is home' do
        it 'returns facility details sorted by closest to user\'s home' do
          VCR.use_cassette('mobile/appointments/get_multiple_mfs_facilities_200',
                           match_requests_on: %i[method uri]) do
            get('/mobile/v0/facilities-info/home', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)
            expect(facilities[0]['id']).to eq('757')
            expect(facilities[1]['id']).to eq('358')
            expect(response.body).to match_json_schema('facilities_info')
          end
        end
      end

      context 'is current' do
        it 'returns facility details sorted by closest to current location' do
          VCR.use_cassette('mobile/appointments/get_multiple_mfs_facilities_200',
                           match_requests_on: %i[method uri]) do
            get('/mobile/v0/facilities-info/current', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)
            expect(facilities[0]['id']).to eq('358')
            expect(facilities[1]['id']).to eq('757')
            expect(response.body).to match_json_schema('facilities_info')
          end
        end

        context 'when current location params are missing' do
          it 'returns an error' do
            VCR.use_cassette('mobile/appointments/get_multiple_mfs_facilities_200',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/facilities-info/current', headers: iam_headers, params: nil
              expect(response).to have_http_status(:bad_request)
              expect(response.body).to match_json_schema('errors')
            end
          end
        end
      end

      context 'is alphabetical' do
        it 'returns facility details sorted alphabetically' do
          VCR.use_cassette('mobile/appointments/get_multiple_mfs_facilities_200',
                           match_requests_on: %i[method uri]) do
            get('/mobile/v0/facilities-info/alphabetical', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)
            expect(facilities[0]['id']).to eq('358')
            expect(facilities[1]['id']).to eq('757')
            expect(response.body).to match_json_schema('facilities_info')
          end
        end
      end

      context 'is appointments' do
        context 'when appointments are in cache' do
          before do
            Mobile::V0::Appointment.set_cached(user, appointments)
          end

          it 'returns facility details sorted by most recent appointment' do
            VCR.use_cassette('mobile/appointments/get_multiple_mfs_facilities_200',
                             match_requests_on: %i[method uri]) do
              get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
              expect(response).to have_http_status(:ok)
              expect(facilities[0]['id']).to eq('358')
              expect(facilities[1]['id']).to eq('757')
              expect(response.body).to match_json_schema('facilities_info')
            end
          end
        end

        context 'when appointments cache is set but empty' do
          before do
            Mobile::V0::Appointment.set_cached(user, [])
          end

          it 'returns facility details sorted alphabetically' do
            VCR.use_cassette('mobile/appointments/get_multiple_facilities_200', match_requests_on: %i[method uri]) do
              get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
              expect(response).to have_http_status(:ok)
              expect(facilities[0]['name']).to eq('American Lake VA Medical Center')
              expect(facilities[1]['name']).to eq('Ayton VA Medical Center')
              expect(facilities[2]['name']).to eq('Cheyenne VA Medical Center')
              expect(response.body).to match_json_schema('facilities_info')
            end
          end
        end

        context 'when appointments cache is nil' do
          before do
            allow(Rails.logger).to receive(:info)
          end

          it 'logs the cache is nil and still returns alphabetized facilities' do
            VCR.use_cassette('mobile/appointments/get_multiple_facilities_200', match_requests_on: %i[method uri]) do
              get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
              expect(Rails.logger).to have_received(:info).with('mobile facilities info appointments cache nil',
                                                                user_uuid: '3097e489-ad75-5746-ab1a-e0aabc1b426a')
              expect(response).to have_http_status(:ok)
              expect(facilities[0]['name']).to eq('American Lake VA Medical Center')
              expect(facilities[1]['name']).to eq('Ayton VA Medical Center')
              expect(facilities[2]['name']).to eq('Cheyenne VA Medical Center')
              expect(response.body).to match_json_schema('facilities_info')
            end
          end
        end

        context 'when only one appointment is in cache' do
          before do
            matching_appointments = appointments.select { |appointment| appointment.facility_id == '358' }
            Mobile::V0::Appointment.set_cached(user, matching_appointments)
          end

          it 'orders starting with that appointment\'s facility with remaining facilities sorted alphabetically' do
            VCR.use_cassette('mobile/appointments/get_multiple_facilities_200', match_requests_on: %i[method uri]) do
              get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
              expect(response).to have_http_status(:ok)

              expect(facilities[0]['name']).to eq('Cheyenne VA Medical Center')
              expect(facilities[1]['name']).to eq('American Lake VA Medical Center')
              expect(facilities[2]['name']).to eq('Ayton VA Medical Center')
              expect(response.body).to match_json_schema('facilities_info')
            end
          end
        end
      end

      context 'is unknown' do
        it 'raises error when sorting by unknown sorting method' do
          expected_error_message = [{ 'title' => 'Invalid field value',
                                      'detail' => '"test" is not a valid value for "sort"',
                                      'code' => '103',
                                      'status' => '400' }]

          VCR.use_cassette('mobile/appointments/legacy_get_facilities_for_facilities_info',
                           match_requests_on: %i[method uri]) do
            get('/mobile/v0/facilities-info/test', headers: iam_headers, params:)
            expect(response).to have_http_status(:bad_request)
            expect(response.parsed_body['errors']).to eq(expected_error_message)
          end
        end
      end
    end
  end
end
