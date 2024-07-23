# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'doc_helpers.rb')

def openapi_spec
  "modules/appeals_api/app/swagger/appealable_issues/v0/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength
RSpec.describe 'Appealable Issues', openapi_spec:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  path '/appealable-issues/{decisionReviewType}' do
    get 'Returns all appealable issues for a specific Veteran.' do
      tags 'Appealable Issues'
      operationId 'getAppealableIssues'
      description 'Returns all issues associated with a Veteran that have been decided ' \
                  'as of the `receiptDate`. Not all issues returned are guaranteed to be eligible for appeal.'
      security DocHelpers.oauth_security_config(
        AppealsApi::AppealableIssues::V0::AppealableIssuesController::OAUTH_SCOPES[:GET]
      )
      consumes 'application/json'
      produces 'application/json'

      parameter(
        parameter_from_schema('appealable_issues/v0/params.json', 'properties', 'decisionReviewType').merge({ in: :path })
      )

      parameter(
        parameter_from_schema('appealable_issues/v0/params.json', 'properties', 'benefitType').merge({ in: :query })
      )

      parameter(
        parameter_from_schema('appealable_issues/v0/params.json', 'properties', 'receiptDate').merge({ in: :query })
      )

      parameter(
        parameter_from_schema('appealable_issues/v0/params.json', 'properties', 'icn').merge(
          {
            in: :query,
            required: false
          }
        )
      )

      let(:decisionReviewType) { 'higher-level-reviews' }
      let(:receiptDate) { '2019-12-01' }
      let(:benefitType) { 'compensation' }

      mpi_cassette = 'mpi/find_candidate/valid'
      default_cassettes = ['caseflow/notice_of_disagreements/contestable_issues', mpi_cassette]
      veteran_scopes = %w[veteran/AppealableIssues.read]
      expected_icn = '1012832025V743496'

      response '200', 'Retrieve all appealable issues for a Veteran' do
        let(:decisionReviewType) { 'notice-of-disagreements' }

        schema '$ref' => '#/components/schemas/appealableIssues'

        describe 'with veteran-scoped token' do
          it_behaves_like 'rswag example',
                          desc: "with a veteran-scoped token (no 'icn' parameter necessary)",
                          extract_desc: true,
                          cassette: default_cassettes,
                          scopes: veteran_scopes
        end

        describe 'with representative-scoped token' do
          let(:icn) { expected_icn }

          it_behaves_like 'rswag example',
                          desc: "with a representative-scoped token ('icn' parameter is necessary)",
                          extract_desc: true,
                          cassette: default_cassettes,
                          scopes: %w[representative/AppealableIssues.read]
        end

        describe 'with system-scoped token' do
          let(:icn) { expected_icn }

          it_behaves_like 'rswag example',
                          desc: "with a system-scoped token ('icn' parameter is necessary)",
                          extract_desc: true,
                          cassette: default_cassettes,
                          scopes: %w[system/AppealableIssues.read]
        end
      end

      response '400', 'Missing ICN parameter' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: "with a representative-scoped token and no 'icn' parameter",
                        extract_desc: true,
                        cassette: default_cassettes,
                        scopes: %w[representative/AppealableIssues.read]

        it_behaves_like 'rswag example',
                        desc: "with a system-scoped token and no 'icn' parameter",
                        extract_desc: true,
                        cassette: default_cassettes,
                        scopes: %w[system/AppealableIssues.read]
      end

      response '403', 'Access forbidden' do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:icn) { '1234567890V123456' }

        it_behaves_like 'rswag example',
                        desc: "with a veteran-scoped token and an optional 'icn' parameter that does not match the Veteran's ICN",
                        cassette: default_cassettes,
                        scopes: veteran_scopes
      end

      response '404', 'Veteran record not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'returns a 404 response',
                        cassette: ['caseflow/higher_level_reviews/not_found', mpi_cassette],
                        scopes: veteran_scopes
      end

      response '422', 'Parameter Errors' do
        schema '$ref' => '#/components/schemas/errorModel'

        describe 'bad decisionReviewType' do
          let(:decisionReviewType) { 'invalid' }

          it_behaves_like 'rswag example',
                          cassette: default_cassettes,
                          desc: 'decisionReviewType must be one of: higher-level-reviews, notice-of-disagreements, supplemental-claims',
                          extract_desc: true,
                          scopes: veteran_scopes
        end

        describe 'bad receiptDate' do
          let(:receiptDate) { '1900-01-01' }

          it_behaves_like 'rswag example',
                          cassette: ['caseflow/higher_level_reviews/bad_date', mpi_cassette],
                          desc: 'Bad receipt date for HLR',
                          extract_desc: true,
                          scopes: veteran_scopes
        end

        describe 'bad ICN' do
          let(:icn) { '1234567890' }

          it_behaves_like 'rswag example',
                          cassette: ['caseflow/higher_level_reviews/contestable_issues', mpi_cassette],
                          desc: 'ICN parameter formatted incorrectly',
                          extract_desc: true,
                          scopes: %w[representative/AppealableIssues.read]
        end
      end

      it_behaves_like 'rswag 500 response'

      response '502', 'Unknown upstream error' do
        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'Upstream error from Caseflow service',
                        cassette: ['caseflow/higher_level_reviews/server_error', mpi_cassette],
                        scopes: veteran_scopes
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
