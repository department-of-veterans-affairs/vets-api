# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength
describe 'Contestable Issues', swagger_doc: DocHelpers.output_json_path, type: :request do
  include DocHelpers
  if DocHelpers.decision_reviews?
    let(:apikey) { 'apikey' }
  else
    let(:Authorization) { 'Bearer TEST_TOKEN' }
  end

  path '/contestable_issues/{decision_review_type}' do
    get 'Returns all contestable issues for a specific veteran.' do
      scopes = AppealsApi::ContestableIssues::V0::ContestableIssuesController::OAUTH_SCOPES[:GET]
      tags 'Contestable Issues'
      operationId 'getContestableIssues'

      description 'Returns all issues associated with a Veteran that have been decided ' \
                  'as of the `receiptDate`. Not all issues returned are guaranteed to be eligible for appeal.' \

      security DocHelpers.security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :decision_review_type,
                in: :path, required: true,
                description: 'Scoping of appeal type for associated issues',
                schema: { 'type': 'string', 'enum': %w[higher_level_reviews notice_of_disagreements supplemental_claims] },
                example: 'higher_level_reviews'

      let(:decision_review_type) { 'notice_of_disagreements' }

      parameter name: :benefit_type,
                in: :query,
                description: 'Required if decision review type is Higher Level Review or Supplemental Claims.',
                schema: { 'type': 'string', 'enum': %w[compensation pensionSurvivorsBenefits fiduciary lifeInsurance veteransHealthAdministration veteranReadinessAndEmployment loanGuaranty education nationalCemeteryAdministration] },
                example: 'compensation'

      let(:benefit_type) { '' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:va_receipt_date]
      let(:'X-VA-Receipt-Date') { '1981-01-01' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge(
        {
          required: !DocHelpers.decision_reviews?
        }
      )
      let(:'X-VA-ICN') { '1234567890V123456' } unless DocHelpers.decision_reviews?

      response '200', 'JSON:API response returning all contestable issues for a specific veteran.' do
        schema '$ref' => '#/components/schemas/contestableIssues'

        let(:decision_review_type) { 'notice_of_disagreements' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/notice_of_disagreements/contestable_issues') do
            with_rswag_auth(scopes) do
              submit_request(example.metadata)
            end
          end
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '404', 'Veteran not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '000000000' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }
        let(:decision_review_type) { 'higher_level_reviews' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/not_found') do
            with_rswag_auth(scopes) do
              submit_request(example.metadata)
            end
          end
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        it 'returns a 404 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Parameter Errors' do
        context 'decision_review_type must be one of: higher_level_reviews, notice_of_disagreements, supplemental_claims' do
          schema '$ref' => '#/components/schemas/errorModel'

          let(:benefit_type) { 'compensation' }
          let(:'X-VA-SSN') { '872958715' }
          let(:'X-VA-Receipt-Date') { '1900-01-01' }
          let(:decision_review_type) { 'invalid' }

          before do |example|
            with_rswag_auth(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                examples: {
                  example.metadata[:example_group][:description] => {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end

        context 'Bad receipt date for HLR' do
          schema '$ref' => '#/components/schemas/errorModel'

          let(:benefit_type) { 'compensation' }
          let(:'X-VA-SSN') { '872958715' }
          let(:'X-VA-Receipt-Date') { '1900-01-01' }
          let(:decision_review_type) { 'higher_level_reviews' }

          before do |example|
            VCR.use_cassette('caseflow/higher_level_reviews/bad_date') do
              with_rswag_auth(scopes) do
                submit_request(example.metadata)
              end
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                examples: {
                  example.metadata[:example_group][:description] => {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end

        unless DocHelpers.decision_reviews?
          context 'X-VA-ICN header missing' do
            let(:'X-VA-ICN') { nil }

            schema '$ref' => '#/components/schemas/errorModel'

            before do |example|
              with_rswag_auth(scopes) do
                submit_request(example.metadata)
              end
            end

            after do |example|
              example.metadata[:response][:content] = {
                'application/json' => {
                  examples: {
                    example.metadata[:example_group][:description] => {
                      value: JSON.parse(response.body, symbolize_names: true)
                    }
                  }
                }
              }
            end

            it 'returns a 422 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end
      end

      it_behaves_like 'rswag 500 response'

      response '502', 'Unknown error' do
        # schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json')))
        # #/errors/0/source is a string 'Appeals Caseflow' instead of an object...

        let(:decision_review_type) { 'higher_level_reviews' }
        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/server_error') do
            with_rswag_auth(scopes) do
              submit_request(example.metadata)
            end
          end
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        it 'returns a 502 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength
