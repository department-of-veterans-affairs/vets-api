# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'doc_helpers.rb')

def openapi_spec
  "modules/appeals_api/app/swagger/legacy_appeals/v0/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength
RSpec.describe 'Legacy Appeals', openapi_spec:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  expected_icn = '1012832025V743496'
  cassette = %w[caseflow/legacy_appeals_get_by_ssn mpi/find_candidate/valid]
  veteran_scopes = %w[veteran/LegacyAppeals.read]

  path '/legacy-appeals' do
    get 'Returns eligible appeals in the legacy process for a Veteran.' do
      tags 'Legacy Appeals'
      operationId 'getLegacyAppeals'
      security DocHelpers.oauth_security_config(
        AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]
      )
      consumes 'application/json'
      produces 'application/json'
      description = 'Returns eligible legacy appeals for a Veteran. A legacy appeal is eligible if a statement of ' \
                    'the case (SOC)  or supplemental statement of the case (SSOC) has been declared, and if the ' \
                    'date of declaration is within the last 60 days.'
      description description

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

      response '200', 'Retrieve legacy appeals for the Veteran with the supplied ICN' do
        schema '$ref' => '#/components/schemas/legacyAppeals'

        describe 'with veteran-scoped token' do
          it_behaves_like 'rswag example',
                          desc: "with a veteran-scoped token (no 'icn' parameter necessary)",
                          extract_desc: true,
                          cassette:,
                          scopes: veteran_scopes
        end

        describe 'with representative-scoped token' do
          let(:icn) { expected_icn }

          it_behaves_like 'rswag example',
                          desc: "with a representative-scoped token ('icn' parameter is necessary)",
                          extract_desc: true,
                          cassette:,
                          scopes: %w[representative/LegacyAppeals.read]
        end

        describe 'with system-scoped token' do
          let(:icn) { expected_icn }

          it_behaves_like 'rswag example',
                          desc: "with a system-scoped token ('icn' parameter is necessary)",
                          extract_desc: true,
                          cassette:,
                          scopes: %w[system/LegacyAppeals.read]
        end
      end

      response '400', 'Missing ICN parameter' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: "with a representative-scoped token and no 'icn' parameter",
                        extract_desc: true,
                        cassette:,
                        scopes: %w[representative/LegacyAppeals.read]

        it_behaves_like 'rswag example',
                        desc: "with a system-scoped token and no 'icn' parameter",
                        extract_desc: true,
                        cassette:,
                        scopes: %w[system/LegacyAppeals.read]
      end

      response '403', 'Access forbidden' do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:icn) { '1234567890V123456' }

        it_behaves_like 'rswag example',
                        desc: "with a veteran-scoped token and an optional 'icn' parameter that does not match the Veteran's ICN",
                        cassette:,
                        scopes: veteran_scopes
      end

      response '404', 'Veteran record not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'returns a 404 response',
                        cassette: %w[caseflow/legacy_appeals_no_veteran_record mpi/find_candidate/valid],
                        scopes: veteran_scopes
      end

      response '422', "Invalid 'icn' parameter" do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:icn) { '12345' }

        it_behaves_like 'rswag example',
                        desc: 'when ICN is formatted incorrectly',
                        extract_desc: true,
                        cassette:,
                        scopes: veteran_scopes
      end

      it_behaves_like 'rswag 500 response'

      response '502', 'Unknown upstream error' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'Upstream error from Caseflow service',
                        cassette: %w[mpi/find_candidate/valid caseflow/legacy_appeals_server_error],
                        scopes: veteran_scopes
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
