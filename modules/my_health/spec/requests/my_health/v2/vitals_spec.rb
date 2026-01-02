# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/service'

RSpec.describe 'MyHealth::V2::AllergiesController', :skip_json_api_validation, type: :request do
  let(:user_id) { '11898795' }
  let(:default_params) { { start_date: '2024-01-01', end_date: '2025-05-31' } }
  let(:path) { '/my_health/v2/medical_records/vitals' }

  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }
  let(:vitals_flipper) { :mhv_accelerated_delivery_vital_signs_enabled }

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv) }

  before do
    Timecop.freeze('2025-06-02T08:00:00Z')
    sign_in_as(current_user)
    allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(vitals_flipper, instance_of(User)).and_return(true)
  end

  after do
    Timecop.return
  end

  describe 'GET /my_health/v2/medical_records/vitals#index' do
    context 'happy path' do
      it 'returns a successful response' do
        VCR.use_cassette('unified_health_data/get_vitals_200', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/vitals', headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data'].count).to eq(4)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].first['type']).to eq('observation')
        expect(json_response['data'].first).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response['data'].first['attributes']).to include(
          'id',
          'name',
          'date',
          'measurement',
          'type',
          'location',
          'notes'
        )
      end

      it 'returns a successful response with an empty data array' do
        VCR.use_cassette('unified_health_data/get_vitals_no_records', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/vitals',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to eq([])
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_vitals)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_vitals_200') do
          get '/my_health/v2/medical_records/vitals',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_vitals)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_vitals_200') do
          get '/my_health/v2/medical_records/vitals',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
