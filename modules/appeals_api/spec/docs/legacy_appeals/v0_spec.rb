# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'doc_helpers.rb')

def swagger_doc
  "modules/appeals_api/app/swagger/legacy_appeals/v0/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup
RSpec.describe 'Legacy Appeals', swagger_doc:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  before do
    mpi_response = create(:find_profile_response, profile: build(:mpi_profile))
    allow_any_instance_of(MPI::Service)
      .to receive(:find_profile_by_identifier)
      .with(identifier: icn, identifier_type: MPI::Constants::ICN).and_return(mpi_response)
  end

  path '/legacy-appeals' do
    get 'Returns eligible appeals in the legacy process for a Veteran.' do
      scopes = AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]

      tags 'Legacy Appeals'
      operationId 'getLegacyAppeals'
      security DocHelpers.oauth_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'
      description = 'Returns eligible legacy appeals for a Veteran. A legacy appeal is eligible if a statement of ' \
                    'the case (SOC)  or supplemental statement of the case (SSOC) has been declared, and if the ' \
                    'date of declaration is within the last 60 days.'
      description description

      parameter(
        parameter_from_schema('legacy_appeals/v0/params.json', 'properties', 'icn')
          .merge({ in: :query, required: true })
      )

      let(:icn) { '1012832025V743496' }

      response '200', 'Returns eligible legacy appeals for a Veteran' do
        schema '$ref' => '#/components/schemas/legacyAppeals'

        it_behaves_like 'rswag example',
                        desc: 'returns a 200 response',
                        cassette: 'caseflow/legacy_appeals_get_by_ssn',
                        scopes:
      end

      response '404', 'Veteran record not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'returns a 404 response',
                        cassette: 'caseflow/legacy_appeals_no_veteran_record',
                        scopes:
      end

      response '422', 'Header Errors' do
        schema '$ref' => '#/components/schemas/errorModel'

        context 'malformed ICN' do
          let(:icn) { '12345' }

          it_behaves_like 'rswag example',
                          desc: 'when ICN formatted incorrectly',
                          extract_desc: true,
                          scopes:
        end
      end

      it_behaves_like 'rswag 500 response'

      response '502', 'Unknown Error' do
        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     properties: {
                       status: {
                         type: 'string',
                         example: '502'
                       },
                       detail: {
                         type: 'string',
                         example: 'Received a 500 response from the upstream server'
                       },
                       code: {
                         type: 'string',
                         example: 'CASEFLOWSTATUS500'
                       },
                       title: {
                         type: 'string',
                         example: 'Bad Gateway'
                       }
                     }
                   }
                 }
               }

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        # rubocop:disable RSpec/NoExpectationExample
        it 'returns a 502 response' do |_example|
          # NOOP
        end
        # rubocop:enable RSpec/NoExpectationExample
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup
