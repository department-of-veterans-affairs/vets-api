# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V1::AllergyIntolerances', :skip_json_api_validation, type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let(:user_id) { '11898795' }
  let(:default_params) { { start_date: '2024-01-01', end_date: '2025-05-31' } }
  let(:path) { '/mobile/v1/health/allergy-intolerances' }
  let!(:current_user) { sis_user(icn: '1000123456V123456') }

  before do
    Timecop.freeze('2025-06-02T08:00:00Z')
    allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_enabled,
                                              instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_allergies_enabled,
                                              instance_of(User)).and_return(true)
  end

  after do
    Timecop.return
  end

  describe 'GET /mobile/v1/health/allergy-intolerances#index' do
    context 'happy path' do
      it 'returns a successful response with default pagination params' do
        VCR.use_cassette('unified_health_data/get_allergies_200', match_requests_on: %i[method path]) do
          # Don't pass pagination params, and let the controller use the defaults
          get '/mobile/v1/health/allergy-intolerances', headers: sis_headers
        end
        expect(response).to be_successful
        assert_schema_conform(200)
        json_response = JSON.parse(response.body)

        expect(json_response).to match_json_schema('v1/allergy_v1')

        # default params are page[number]=1 and page[size]=10
        # Only 10 allergies are returned after filtering by clinicalStatus: active
        expect(json_response['meta']['pagination']).to eq({
                                                            'totalPages' => 1,
                                                            'totalEntries' => 10,
                                                            'currentPage' => 1,
                                                            'perPage' => 10
                                                          })
        expect(json_response['data'].count).to eq(10)
        expect(json_response['data'].first['type']).to eq('allergy')
      end

      it 'returns a successful response with when given pagination params' do
        VCR.use_cassette('unified_health_data/get_allergies_200', match_requests_on: %i[method path]) do
          get '/mobile/v1/health/allergy-intolerances?page[number]=1&page[size]=100',
              headers: sis_headers
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to match_json_schema('v1/allergy_v1')

        # Only 10 allergies are returned after filtering by clinicalStatus: active
        expect(json_response['meta']['pagination']).to eq({
                                                            'totalPages' => 1,
                                                            'totalEntries' => 10,
                                                            'currentPage' => 1,
                                                            'perPage' => 100
                                                          })
        expect(json_response['data'].count).to eq(10)
        expect(json_response['data'].first['type']).to eq('allergy')
      end

      it 'returns a successful response with an empty data array' do
        VCR.use_cassette('unified_health_data/get_allergies_no_records', match_requests_on: %i[method path]) do
          get '/mobile/v1/health/allergy-intolerances',
              headers: sis_headers
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to match_json_schema('v1/allergy_v1')

        expect(json_response['data']).to eq([])
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_allergies)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_allergies_200') do
          get '/mobile/v1/health/allergy-intolerances',
              headers: sis_headers
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_allergies)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_allergies_200') do
          get '/mobile/v1/health/allergy-intolerances',
              headers: sis_headers
        end
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context 'feature flags disabled' do
      it 'returns a 403 when the allergies feature flag is disabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_allergies_enabled,
                                                  instance_of(User)).and_return(false)
        get '/mobile/v1/health/allergy-intolerances', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
        expect(json_response['error']['message']).to eq('This feature is not currently available')
      end

      it 'returns a 404 when the main accelerated feature flag is disabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_enabled,
                                                  instance_of(User)).and_return(false)
        get '/mobile/v1/health/allergy-intolerances', headers: sis_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
