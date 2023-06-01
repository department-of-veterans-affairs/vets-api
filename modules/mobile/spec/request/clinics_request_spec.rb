# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'clinics', type: :request do
  include JsonSchemaMatchers

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'PUT /mobile/v0/appointments/facilities/:facility_id/clinics', :aggregate_failures do
    context 'when both facility id and service type is found' do
      let(:facility_id) { '983' }
      let(:params) { { service_type: 'audiology' } }

      it 'returns 200' do
        VCR.use_cassette('mobile/appointments/get_facility_clinics_200', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params:, headers: iam_headers

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('clinic')
        end
      end
    end

    context 'when facility id is not found' do
      let(:facility_id) { '999AA' }
      let(:params) { { service_type: 'audiology' } }

      it 'returns 200 with empty response' do
        VCR.use_cassette('mobile/appointments/get_facility_clinics_bad_facility_id_200',
                         match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params:, headers: iam_headers

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body['data']).to eq([])
        end
      end
    end

    context 'when service type is not found' do
      let(:facility_id) { '983' }
      let(:params) { { service_type: 'badservice' } }

      it 'returns bad request' do
        VCR.use_cassette('mobile/appointments/get_facility_clinics_bad_service_400',
                         match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params:, headers: iam_headers

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.parsed_body.dig('errors', 0, 'source',
                                                     'vamfBody'))['message']).to eq('clinicalService: param is invalid')
        end
      end
    end
  end

  describe 'PUT /mobile/v0/appointments/facilities/{facililty_id}/clinics/{clinic_id}/slots', :aggregate_failures do
    context 'when both facility id and clinic id is found' do
      let(:facility_id) { '983' }
      let(:clinic_id) { '1081' }
      let(:params) { { start_date: '2021-10-26T00:00:00Z', end_date: '2021-12-30T23:59:59Z' } }

      it 'returns 200' do
        VCR.use_cassette('mobile/appointments/get_available_slots_200', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics/#{clinic_id}/slots", params:,
                                                                                              headers: iam_headers

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('clinic_slot')
        end
      end
    end

    context 'when start and end date are not given' do
      let(:facility_id) { '983' }
      let(:clinic_id) { '1081' }
      let(:current_time) { '2021-10-25T01:00:00Z' }

      before do
        Timecop.freeze(Time.zone.parse(current_time))
      end

      after do
        Timecop.return
      end

      it 'defaults time from now to 2 months from now' do
        VCR.use_cassette('mobile/appointments/get_available_slots_200_no_start_end_date',
                         match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics/#{clinic_id}/slots", headers: iam_headers

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('clinic_slot')

          parsed_response = response.parsed_body['data']
          min_start_date = parsed_response.map { |x| x.dig('attributes', 'startDate') }.min
          max_end_date = parsed_response.map { |x| x.dig('attributes', 'endDate') }.max
          expect(min_start_date).to be > current_time
          expect(max_end_date).to be < '2021-12-25T23:59:59Z'
        end
      end
    end

    context 'with a upstream service 500 response' do
      let(:facility_id) { '983' }
      let(:clinic_id) { '1081' }
      let(:params) { { start_date: '2021-10-01T00:00:00Z', end_date: '2021-12-31T23:59:59Z' } }

      it 'returns a 502 error' do
        VCR.use_cassette('mobile/appointments/get_available_slots_500', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics/#{clinic_id}/slots", params:,
                                                                                              headers: iam_headers

          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
