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

      if parsed_response['data'].any?
        condition = parsed_response['data'].first
        expect(condition).to have_key('id')
        expect(condition).to have_key('type')
        expect(condition).to have_key('attributes')
        expect(condition['type']).to eq('condition')

        attributes = condition['attributes']
        expect(attributes).to have_key('id')
        expect(attributes).to have_key('name')
        expect(attributes).to have_key('date')
        expect(attributes).to have_key('provider')
        expect(attributes).to have_key('facility')
        expect(attributes).to have_key('comments')

        expect(attributes['id']).to be_a(String)
        expect(attributes['name']).to be_a(String)
        expect(attributes['date']).to be_a(String).or(be_nil)
        expect(attributes['provider']).to be_a(String).or(be_nil)
        expect(attributes['facility']).to be_a(String).or(be_nil)
        expect(attributes['comments']).to be_an(Array).or(be_nil)
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
    let(:show_path) { "#{path}/condition-12345" }

    it 'returns a single condition successfully' do
      VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
        get show_path, headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to have_key('data')
      expect(parsed_response['data']).to be_a(Hash)
      expect(parsed_response['data']['id']).to eq('condition-12345')

      condition = parsed_response['data']
      expect(condition).to have_key('id')
      expect(condition).to have_key('type')
      expect(condition).to have_key('attributes')
      expect(condition['type']).to eq('condition')

      attributes = condition['attributes']
      expect(attributes).to have_key('id')
      expect(attributes).to have_key('name')
      expect(attributes).to have_key('date')
      expect(attributes).to have_key('provider')
      expect(attributes).to have_key('facility')
      expect(attributes).to have_key('comments')

      expect(attributes['id']).to be_a(String)
      expect(attributes['name']).to be_a(String)
      expect(attributes['date']).to be_a(String).or(be_nil)
      expect(attributes['provider']).to be_a(String).or(be_nil)
      expect(attributes['facility']).to be_a(String).or(be_nil)
      expect(attributes['comments']).to be_an(Array).or(be_nil)
    end

    it 'returns 404 when condition not found' do
      VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
        get "#{path}/nonexistent-id", headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to have_http_status(:not_found)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to have_key('errors')
      expect(parsed_response['errors'].first['title']).to eq('Condition not found')
    end

    it 'returns error response when there is a client error' do
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
