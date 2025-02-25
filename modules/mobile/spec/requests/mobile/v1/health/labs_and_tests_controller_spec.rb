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

    it 'returns the correct medical records' do
      json_response = JSON.parse(response.body)
      expect(json_response[0]).to eq({
        "id" => "e9513940-bf84-4120-ac9c-718f537b00e0",
        "type" => "DiagnosticReport",
        "attributes" => {
          "display" => "CH",
          "testCode" => "CH",
          "dateCompleted" => "2025-01-23T22:06:02Z",
          "sampleSite" => "SERUM",
          "encodedData" => "",
          "location" => "CHYSHR TEST LAB",
          "orderedBy" => "MARCI P MCGUIRE",
          "observations" => [
            { "testCode" => "GLUCOSE", "encodedData" => "", "valueQuantity" => "99 mg/dL", "referenceRange" => "70 - 110", "status" => "final", "comments" => "" },
            { "testCode" => "UREA NITROGEN", "encodedData" => "", "valueQuantity" => "200 mg/dL", "referenceRange" => "7 - 18", "status" => "final", "comments" => "" },
            { "testCode" => "CREATININE", "encodedData" => "", "valueQuantity" => "5 mg/dL", "referenceRange" => "0.6 - 1.3", "status" => "final", "comments" => "" },
            { "testCode" => "SODIUM", "encodedData" => "", "valueQuantity" => "8 meq/L", "referenceRange" => "136 - 145", "status" => "final", "comments" => "" },
            { "testCode" => "POTASSIUM", "encodedData" => "", "valueQuantity" => "24 meq/L", "referenceRange" => "3.5 - 5.1", "status" => "final", "comments" => "" },
            { "testCode" => "CHLORIDE", "encodedData" => "", "valueQuantity" => "2 meq/L", "referenceRange" => "98 - 107", "status" => "final", "comments" => "" },
            { "testCode" => "CO2", "encodedData" => "", "valueQuantity" => "2 meq/L", "referenceRange" => "22 - 29", "status" => "final", "comments" => "" }
            ]
          }
        }
      )
    end
  end
end
