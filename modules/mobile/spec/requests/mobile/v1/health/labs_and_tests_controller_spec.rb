require 'rails_helper'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V1::LabsAndTestsController', :skip_json_api_validation, type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '1000000000V000000') }
  let(:default_params) { { "patient-id": "1000000000V000000" } }

  describe 'GET /mobile/v1/health/labs-and-tests' do
    before do
      VCR.use_cassette('mobile/unified_health_data/get_labs', match_requests_on: %i[method uri]) do
        get '/mobile/v1/health/labs-and-tests', headers: sis_headers, params: default_params
      end
    end

    it 'returns a successful response' do
      expect(response).to be_successful
    end
  end
end
