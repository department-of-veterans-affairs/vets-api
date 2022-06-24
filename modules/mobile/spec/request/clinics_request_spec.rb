# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'clinics', type: :request do
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

  describe 'PUT /mobile/v0/appointments/facilities/:facility_id/clinics', :aggregate_failures do
    context 'when both facility id and service type is found' do
      let(:facility_id) { '983' }
      let(:params) { { service_type: 'audiology' } }

      it 'returns 200' do
        VCR.use_cassette('appointments/get_facility_clinics_200', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params: params, headers: iam_headers

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('clinic')
        end
      end
    end

    context 'when facility id is not found' do
      let(:facility_id) { '999AA' }
      let(:params) { { service_type: 'audiology' } }

      it 'returns 200 with empty response' do
        VCR.use_cassette('appointments/get_facility_clinics_bad_facility_id_200', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params: params, headers: iam_headers

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body['data']).to eq([])
        end
      end
    end

    context 'when service type is not found' do
      let(:facility_id) { '983' }
      let(:params) { { service_type: 'badservice' } }

      it 'returns bad request' do
        VCR.use_cassette('appointments/get_facility_clinics_bad_service_400', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params: params, headers: iam_headers

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.parsed_body.dig('errors', 0, 'source',
                                                     'vamfBody'))['message']).to eq('clinicalService: param is invalid')
        end
      end
    end
  end
end
