# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'MyHealth::V2::ConditionsController', :skip_json_api_validation, type: :request do
  let(:path) { '/my_health/v2/medical_records/conditions' }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/conditions' do
    context 'happy path' do
      it 'returns a successful response' do
        allow(UniqueUserEvents).to receive(:log_events)
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].first['type']).to eq('condition')
        expect(json_response['data'].first).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response['data'].first['attributes']).to include(
          'id',
          'name',
          'date',
          'provider',
          'facility',
          'comments'
        )

        # There are 4 conditions in the cassette, but 1 is filtered out:
        # - 1 with status 'entered-in-error'
        expect(json_response['data'].size).to eq(3)
        # status of entered-in-error should be excluded from results
        expect(json_response['data'].find { |c| c['id'] == 'p1534246681' }).to be_nil
        # condition with no date should be included in results
        expect(json_response['data'].find { |c| c['id'] == '2b4de3e7-0ced-43c6-9a8a-336b9171f4df' }).to be_present

        # Verify event logging was called
        expect(UniqueUserEvents).to have_received(:log_events).with(
          user: anything,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_CONDITIONS_ACCESSED
          ]
        )
      end

      it 'returns a successful response with an empty data array' do
        VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to eq([])
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_conditions_200') do
          get path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_conditions_200') do
          get path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end

  describe 'GET /my_health/v2/medical_records/conditions/:id' do
    let(:show_path) { "#{path}/2afda724-55ca-4a78-b815-3e6d9c35cd15" }

    context 'happy path' do
      it 'returns a successful response for a single condition' do
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get show_path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data']['type']).to eq('condition')
        expect(json_response['data']).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response['data']['attributes']).to include(
          'id',
          'name',
          'date',
          'provider',
          'facility',
          'comments'
        )
      end

      it 'returns a 404 not found' do
        VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
          get "#{path}/nonexistent-id", headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_condition)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_conditions_200') do
          get show_path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_condition)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_conditions_200') do
          get show_path, headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
