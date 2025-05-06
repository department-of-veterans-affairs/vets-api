# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

def openapi_spec
  "modules/appeals_api/app/swagger/appeals_status/v1/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength
describe 'Appeals Status', openapi_spec:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  path '/appeals' do
    get 'Retrieve appeals status for the Veteran with the supplied ICN' do
      tags 'Appeals Status'
      operationId 'getAppealStatus'

      description "Returns a list of all known appeal records for the given Veteran. Includes details of each appeal's current status, priority, and history of updates."

      security DocHelpers.oauth_security_config(AppealsApi::V1::AppealsController::OAUTH_SCOPES[:GET])
      consumes 'application/json'
      produces 'application/json'

      parameter(
        parameter_from_schema('shared/v0/icn.json', 'properties', 'icn').merge(
          {
            name: :icn,
            in: :query,
            description: "Veteran's Master Person Index (MPI) Integration Control Number (ICN). Optional when using a veteran-scoped token. Required when using a representative- or system-scoped token.",
            required: false
          }
        )
      )

      cassette = %w[caseflow/appeals mpi/find_candidate/valid]
      expected_icn = '1012832025V743496'
      success_response_schema = {
        type: 'object',
        properties: { data: { '$ref': '#/components/schemas/appeals' } },
        required: ['data']
      }

      response '200', 'Successfully fetching appeals' do
        schema success_response_schema

        describe 'success with veteran-scoped token' do
          it_behaves_like 'rswag example',
                          desc: "with a veteran-scoped token (no 'icn' parameter necessary)",
                          extract_desc: true,
                          cassette:,
                          scopes: %w[veteran/AppealsStatus.read]
        end

        describe 'success with representative-scoped token' do
          let(:icn) { expected_icn }

          it_behaves_like 'rswag example',
                          desc: "with a representative-scoped token ('icn' parameter is necessary)",
                          extract_desc: true,
                          cassette:,
                          scopes: %w[representative/AppealsStatus.read]
        end

        describe 'success with system-scoped token' do
          let(:icn) { expected_icn }

          it_behaves_like 'rswag example',
                          desc: "with a system-scoped token ('icn' parameter is necessary)",
                          extract_desc: true,
                          cassette:,
                          scopes: %w[system/AppealsStatus.read]
        end
      end

      response '400', 'Missing parameters' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: "with a representative-scoped token and no 'icn' parameter",
                        extract_desc: true,
                        cassette:,
                        scopes: %w[representative/AppealsStatus.read]

        it_behaves_like 'rswag example',
                        desc: "with a system-scoped token and no 'icn' parameter",
                        extract_desc: true,
                        cassette:,
                        scopes: %w[system/AppealsStatus.read]
      end

      response '403', 'Forbidden requests' do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:icn) { '1234567890V123456' }

        it_behaves_like 'rswag example',
                        desc: "with a veteran-scoped token and an optional 'icn' parameter that does not match the Veteran's ICN",
                        extract_desc: true,
                        cassette:,
                        scopes: %w[veteran/AppealsStatus.read]
      end

      response '404', 'Not Found' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'Not Found',
                        extract_desc: true,
                        cassette: %w[caseflow/not_found mpi/find_candidate/valid],
                        scopes: %w[veteran/AppealsStatus.read]
      end

      response '422', "Invalid 'icn' parameter" do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:scopes) { %w[representative/AppealsStatus.read] }
        let(:icn) { '000000000V00000' }
        let(:cassette) { %w[caseflow/invalid_ssn mpi/find_candidate/valid] }

        it_behaves_like 'rswag example',
                        desc: "with an incorrectly formatted 'icn' parameter",
                        extract_desc: true,
                        cassette:,
                        scopes: %w[veteran/AppealsStatus.read]
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
