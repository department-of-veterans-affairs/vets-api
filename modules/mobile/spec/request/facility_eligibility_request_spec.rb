# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'Facility Eligibility', type: :request do
  include JsonSchemaMatchers

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('9000682')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /mobile/v0/facility/eligibility' do
    context 'valid parameters' do
      context 'with pagination parameters' do
        let(:params) do
          { serviceType: 'primaryCare', facilityIds: %w[100 101 102 103], type: 'request',
            page: { number: 2, size: 2 } }
        end

        before do
          VCR.use_cassette('mobile/facility_eligibility/get_patient_appointment_metadata_facility_102',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/facility_eligibility/get_patient_appointment_metadata_facility_103',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/facility/eligibility', params:, headers: iam_headers
            end
          end
        end

        it 'returns 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns expected facilities based on page parameters' do
          parsed_response = response.parsed_body['data']
          expect(parsed_response.map { |x| x.dig('attributes', 'facilityId') }).to eq(%w[102 103])
        end

        it 'forms expected meta data' do
          expect(response.parsed_body['meta']).to eq(
            { 'pagination' => { 'currentPage' => 2, 'perPage' => 2,
                                'totalPages' => 2, 'totalEntries' => 4 } }
          )
        end
      end

      context 'without pagination parameters' do
        let(:params) do
          { serviceType: 'primaryCare', facilityIds: %w[100 101 102 103], type: 'request' }
        end

        before do
          VCR.use_cassette('mobile/facility_eligibility/get_patient_appointment_metadata_facility_100',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/facility_eligibility/get_patient_appointment_metadata_facility_101',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/facility_eligibility/get_patient_appointment_metadata_facility_102',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments/facility/eligibility', params:, headers: iam_headers
              end
            end
          end
        end

        it 'returns 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'matches schema' do
          expect(response.body).to match_json_schema('facility_eligibility')
        end

        it 'forms expected meta data with default pagination values' do
          expect(response.parsed_body['meta']).to eq(
            { 'pagination' => { 'currentPage' => 1, 'perPage' => 3,
                                'totalPages' => 2, 'totalEntries' => 4 } }
          )
        end
      end
    end

    context 'Invalid parameters' do
      context 'when invalid serviceType is provided' do
        let(:params) do
          { serviceType: 'notatype', facilityIds: ['942'], type: 'request' }
        end

        before do
          get '/mobile/v0/appointments/facility/eligibility', params:, headers: iam_headers
        end

        it 'returns 400 with an error message' do
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns expected error message' do
          expect(response.parsed_body.dig('errors', 0,
                                          'detail')).to eq('"notatype" is not a valid value for "serviceType"')
        end
      end

      context 'bad facility id' do
        let(:params) do
          { serviceType: 'primaryCare', facilityIds: ['1234567'], type: 'request' }
        end

        before do
          VCR.use_cassette('mobile/facility_eligibility/get_patient_appointment_metadata_bad_facility',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments/facility/eligibility', params:, headers: iam_headers
          end
        end

        it 'returns 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'matches schema' do
          expect(response.body).to match_json_schema('facility_eligibility')
        end

        it 'assumes facility exists but does not support requests' do
          expect(response.parsed_body.dig('data', 0, 'attributes', 'reason'))
            .to eq('appointment requests are disabled for the clinical service at the facility')
        end
      end
    end
  end
end
