# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'facilities info', type: :request do
  include JsonSchemaMatchers

  let(:params) { { lat: 40.5, long: 100.1 } }
  let(:user) { FactoryBot.build(:iam_user, :custom_facility_ids, facility_ids: %w[757 358 999]) }

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Settings.mhv).to receive(:facility_range).and_return([[358, 718], [720, 758], [983, 984], [999, 999]])
  end

  va_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures',
                            'va_appointments_for_facility_info.json')
  va_json = File.read(va_path)
  va_appointments = Mobile::V0::Adapters::VAAppointments.new.parse(
    JSON.parse(va_json, symbolize_names: true)
  )

  appointments = va_appointments.sort_by(&:start_date_utc)

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/facilities-info' do
    context 'when there are appointments' do
      before do
        Mobile::V0::Appointment.set_cached(user, appointments)
      end

      it 'returns facility details sorted by closest to home' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/home', headers: iam_headers, params:)
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('757')
          expect(facilities[1]['id']).to eq('358')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted by closest to current location' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/current', headers: iam_headers, params:)
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted alphabetically' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/alphabetical', headers: iam_headers, params:)
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted by most recent appointment' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      context 'when current location params are missing and sort by current is selected' do
        it 'returns an error' do
          VCR.use_cassette('appointments/get_multiple_mfs_facilities_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/facilities-info/current', headers: iam_headers, params: nil
            expect(response).to have_http_status(:bad_request)
            expect(response.body).to match_json_schema('errors')
          end
        end
      end

      it 'raises error when sorting by unknown sorting method' do
        expected_error_message = [{ 'title' => 'Invalid field value',
                                    'detail' => '"test" is not a valid value for "sort"',
                                    'code' => '103',
                                    'status' => '400' }]

        VCR.use_cassette('appointments/legacy_get_facilities_for_facilities_info',
                         match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/test', headers: iam_headers, params:)
          expect(response.parsed_body['errors']).to eq(expected_error_message)
        end
      end
    end

    context 'when there are no appointments' do
      before do
        Mobile::V0::Appointment.set_cached(user, [])
      end

      it 'returns facility details sorted alphabetically' do
        VCR.use_cassette('appointments/get_multiple_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
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
        VCR.use_cassette('appointments/get_multiple_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
          expect(Rails.logger).to have_received(:info).with('mobile facilities info appointments cache nil',
                                                            user_uuid: '3097e489-ad75-5746-ab1a-e0aabc1b426a')
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['name']).to eq('American Lake VA Medical Center')
          expect(facilities[1]['name']).to eq('Ayton VA Medical Center')
          expect(facilities[2]['name']).to eq('Cheyenne VA Medical Center')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end
    end

    context 'when there is one appointment' do
      before do
        matching_appointments = appointments.select { |appointment| appointment.facility_id == '358' }
        Mobile::V0::Appointment.set_cached(user, matching_appointments)
      end

      it 'remaining facilities are sorted alphabetically' do
        VCR.use_cassette('appointments/get_multiple_facilities_200', match_requests_on: %i[method uri]) do
          get('/mobile/v0/facilities-info/appointments', headers: iam_headers, params:)
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['name']).to eq('Cheyenne VA Medical Center')
          expect(facilities[1]['name']).to eq('American Lake VA Medical Center')
          expect(facilities[2]['name']).to eq('Ayton VA Medical Center')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end
    end
  end
end
