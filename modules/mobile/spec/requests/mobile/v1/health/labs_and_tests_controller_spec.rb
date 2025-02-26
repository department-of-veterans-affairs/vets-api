# frozen_string_literal: true

require 'rails_helper'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V1::LabsAndTestsController', :skip_json_api_validation, type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '1000000000V000000') }
  let(:default_params) { { 'patient-id': '1000000000V000000', start_date: '2024-01-01', end_date: '2024-12-31' } }
  let(:expected_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_response.json'
    ).read)
  end

  describe 'GET /mobile/v1/health/labs-and-tests' do
    before do
      VCR.use_cassette('mobile/unified_health_data/get_labs', match_requests_on: %i[method uri]) do
        get '/mobile/v1/health/labs-and-tests', headers: sis_headers, params: default_params
      end
    end

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'returns the correct medical records' do
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(11)
      expect(json_response[0]).to eq(expected_response)
    end
  end
end
