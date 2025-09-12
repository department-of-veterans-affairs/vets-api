# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/service'

RSpec.describe 'MyHealth::V2::ConditionsController', :skip_json_api_validation, type: :request do
  let(:path) { '/my_health/v2/medical_records/conditions' }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/conditions' do
    it 'returns conditions successfully' do
      VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
        get path, headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to have_key('data')
      expect(parsed_response['data']).to be_an(Array)
    end

    it 'returns conditions with proper data structure and properties' do
      VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
        get path, headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to have_key('data')
      expect(parsed_response['data']).to be_an(Array)
      expect(parsed_response['data']).not_to be_empty

      parsed_response['data'].each do |condition|
        expect(condition).to include(
          'id' => be_a(String),
          'type' => 'condition',
          'attributes' => include(
            'id' => be_a(String),
            'name' => be_a(String),
            'provider' => be_a(String).or(be_nil),
            'facility' => be_a(String).or(be_nil),
            'date' => be_a(String).or(be_nil),
            'comments' => be_an(Array)
          )
        )

        attributes = condition['attributes']
        expect(attributes['id']).not_to be_empty
        expect(attributes['name']).not_to be_empty
        expect(attributes['comments']).to be_an(Array)
      end
    end

    it 'returns empty array when no conditions found' do
      VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
        get path, headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data']).to eq([])
    end

    it 'handles service errors gracefully' do
      allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
        .and_raise(StandardError.new('Service unavailable'))

      get path, headers: { 'X-Key-Inflection' => 'camel' }

      expect(response).to have_http_status(:internal_server_error)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to have_key('errors')
    end
  end

  describe 'GET /my_health/v2/medical_records/conditions/:id' do
    let(:condition_id) { 'condition-12345' }
    let(:show_path) { "#{path}/#{condition_id}" }

    it 'returns a single condition successfully' do
      VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
        get show_path, headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to have_key('data')
      expect(parsed_response['data']).to be_a(Hash)
      expect(parsed_response['data']).to include(
        'id' => condition_id,
        'type' => 'condition',
        'attributes' => include(
          'id' => condition_id,
          'name' => be_a(String),
          'provider' => be_a(String).or(be_nil),
          'facility' => be_a(String).or(be_nil),
          'date' => be_a(String).or(be_nil),
          'comments' => be_an(Array)
        )
      )
    end

    it 'returns a 404 not found when condition does not exist' do
      VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
        get "#{path}/nonexistent-id", headers: { 'X-Key-Inflection' => 'camel' }
      end
      expect(response).to have_http_status(:not_found)
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
