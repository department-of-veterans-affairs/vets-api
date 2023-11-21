# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

def swagger_doc
  "modules/appeals_api/app/swagger/appeals_status/v1/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength, RSpec/RepeatedExample
describe 'Appeals Status', swagger_doc:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  path '/appeals' do
    get 'Retrieve appeals status for the Veteran with the supplied SSN' do
      scopes = AppealsApi::V1::AppealsController::OAUTH_SCOPES[:GET]
      tags 'Appeals Status'
      operationId 'getAppealStatus'

      description "Returns a list of all known appeal records for the given veteran. Includes details of each appeal's current status, priority, and history of updates."

      security DocHelpers.oauth_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      example_icn = '1234567890V543210'
      example_va_user = 'va.api.user+idme.001@gmail.com'

      parameter(
        parameter_from_schema('shared/v0/icn.json', 'properties', 'icn').merge(
          {
            name: :icn,
            in: :query,
            required: true,
            example: example_icn
          }
        )
      )

      let(:icn) { example_icn }

      parameter name: 'X-VA-User',
                in: :header,
                required: true,
                example: example_va_user,
                schema: { type: 'string' },
                description: 'VA username of the person making the request'

      let(:'X-VA-User') { example_va_user }

      let(:caseflow_cassette_name) { 'caseflow/appeals' }
      let(:mpi_cassette_name) { 'mpi/find_candidate/valid' }

      before do |example|
        VCR.use_cassette(caseflow_cassette_name) do
          VCR.use_cassette(mpi_cassette_name) do
            with_rswag_auth(scopes) { submit_request(example.metadata) }
          end
        end
      end

      response '200', 'Appeals retrieved successfully' do
        response_schema = {
          type: 'object',
          properties: { data: { '$ref': '#/components/schemas/appeals' } },
          required: ['data']
        }
        schema response_schema

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '400', "Missing 'icn' parameter" do
        let(:icn) { nil }

        schema '$ref' => '#/components/schemas/errorModel'

        it 'returns a 400 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Invalid ICN' do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:icn) { '000000000V00000' }

        context 'with caseflow error response' do
          before do |example|
            VCR.use_cassette('caseflow/invalid_ssn') do
              with_rswag_auth(scopes) do
                submit_request(example.metadata)
              end
            end
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength, RSpec/RepeatedExample
