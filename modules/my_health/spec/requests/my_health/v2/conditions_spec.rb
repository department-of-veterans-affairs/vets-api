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
end
