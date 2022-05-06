# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'facilities info', type: :request do
  include JsonSchemaMatchers

  let(:params) { { lat: 40.5, long: 100.1 } }
  let(:user) { FactoryBot.build(:iam_user) }

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  va_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures',
                            'va_appointments_for_facility_info.json')
  va_json = File.read(va_path)
  va_appointments = Mobile::V0::Adapters::VAAppointments.new.parse(
    JSON.parse(va_json, symbolize_names: true)
  )

  appointments = (va_appointments).sort_by(&:start_date_utc)

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/facilities-info' do
    context 'when the MFS flag is enabled' do
      before do
        Flipper.enable(:mobile_appointment_use_VAOS_MFS)
        Mobile::V0::Appointment.set_cached(user, appointments)
      end

      after { Flipper.disable(:mobile_appointment_use_VAOS_MFS) }

      it 'returns facility details sorted by closest to home' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/home', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('757')
          expect(facilities[1]['id']).to eq('358')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted by closest to current location' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/current', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted alphabetically' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/alphabetical', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted by most recent appointment' do
        VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/appointments', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      context 'when current location params are missing and sort by current is selected' do
        it 'returns an error' do
          VCR.use_cassette('appointments/get_multiple_mfs_facilities_200', match_requests_on: %i[method uri]) do
            get '/mobile/v0/facilities-info/current', headers: iam_headers, params: nil
            expect(response).to have_http_status(:bad_request)
            expect(response.body).to match_json_schema('errors')
          end
        end
      end
    end

    context 'when the MFS flag is disabled' do
      before do
        Flipper.disable(:mobile_appointment_use_VAOS_MFS)
        Mobile::V0::Appointment.set_cached(user, appointments)
      end

      it 'returns facility details sorted by closest to home' do
        VCR.use_cassette('appointments/legacy_get_facilities_for_facilities_info', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/home', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('757')
          expect(facilities[1]['id']).to eq('358')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted by closest to current location' do
        VCR.use_cassette('appointments/legacy_get_facilities_for_facilities_info', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/current', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('757')
          expect(facilities[1]['id']).to eq('358')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted alphabetically' do
        VCR.use_cassette('appointments/legacy_get_facilities_for_facilities_info', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/alphabetical', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end

      it 'returns facility details sorted by most recent appointment' do
        VCR.use_cassette('appointments/legacy_get_facilities_for_facilities_info', match_requests_on: %i[method uri]) do
          get '/mobile/v0/facilities-info/appointments', headers: iam_headers, params: params
          facilities = response.parsed_body.dig('data', 'attributes', 'facilities')
          expect(response).to have_http_status(:ok)
          expect(facilities[0]['id']).to eq('358')
          expect(facilities[1]['id']).to eq('757')
          expect(response.body).to match_json_schema('facilities_info')
        end
      end
    end
  end
end
