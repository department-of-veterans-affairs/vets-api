# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/service'

RSpec.describe 'MyHealth::V2::ConditionsController', :skip_json_api_validation, type: :request do
  let(:user_id) { '11898795' }

  let(:path) { '/my_health/v2/medical_records/conditions' }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/conditions' do
    context 'happy path' do
      it 'returns a 200 response' do
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }
        end

        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key('data')
        expect(parsed_response['data']).to be_an(Array)

        first_condition = parsed_response['data'].first
        expect(first_condition).to include(
          'id' => 'condition-1',
          'type' => 'condition',
          'attributes' => hash_including(
            'name' => 'Test Condition',
            'provider' => 'Dr. Test',
            'facility' => 'Test Facility',
            'comments' => ['Test comments', 'Follow-up needed']
          )
        )
      end
    end

    context 'no records' do
      it 'returns a 200 response with empty data array' do
        VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }
        end

        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key('data')
        expect(parsed_response['data']).to be_an(Array)
        expect(parsed_response['data']).to be_empty
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
    let(:condition_id) { 'condition-1' }

    context 'happy path' do
      it 'returns a single condition' do
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get "#{path}/#{condition_id}", headers: { 'X-Key-Inflection' => 'camel' }
        end

        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key('data')
        expect(parsed_response['data']).to include(
          'id' => condition_id,
          'type' => 'condition',
          'attributes' => hash_including(
            'name' => 'Test Condition',
            'provider' => 'Dr. Test',
            'facility' => 'Test Facility',
            'comments' => ['Test comments', 'Follow-up needed']
          )
        )
      end
    end

    context 'when condition not found' do
      it 'returns a 404 not found' do
        VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
          get "#{path}/nonexistent", headers: { 'X-Key-Inflection' => 'camel' }
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
          get "#{path}/#{condition_id}", headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_condition)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_conditions_200') do
          get "#{path}/#{condition_id}", headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
