# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require_relative '../../support/swagger_shared_components'

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength

describe 'Contestable Issues', swagger_doc: 'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json', type: :request do
  let(:apikey) { 'apikey' }

  path '/contestable_issues/{decision_review_type}' do
    get 'Returns all contestable issues for a specific veteran.' do
      tags 'Contestable Issues'
      operationId 'getContestableIssues'

      description 'Returns all issues associated with a Veteran that have ' \
                  'not previously been decided ' \
                  'as of the `receiptDate`. Not all issues returned are guaranteed to be eligible for appeal.' \

      security [
        { apikey: [] }
      ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :decision_review_type, in: :path, required: true, type: :string, description: 'Scoping of appeal type for associated issues'
      let(:decision_review_type) { 'notice_of_disagreements' }
      parameter name: :benefit_type, in: :query, type: :string,
                description: 'Benefit Type for the appeal. Required if Decision Review is a Higher Level Review.',
                enum: %w[
                  compensation
                  pensionSurvivorsBenefits
                  fiduciary
                  lifeInsurance
                  veteransHealthAdministration
                  veteranReadinessAndEmployment
                  loanGuaranty
                  education
                  nationalCemeteryAdministration
                ]
      let(:benefit_type) { '' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:va_receipt_date]
      let(:'X-VA-Receipt-Date') { '1981-01-01' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]

      response '200', 'JSON:API response returning all contestable issues for a specific veteran.' do
        schema '$ref' => '#/components/schemas/contestableIssues'

        let(:decision_review_type) { 'notice_of_disagreements' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/notice_of_disagreements/contestable_issues') do
            submit_request(example.metadata)
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
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '000000000' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }
        let(:decision_review_type) { 'higher_level_reviews' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/not_found') do
            submit_request(example.metadata)
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
            submit_request(example.metadata)
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

        context 'Bad receipt date for  HLR' do
          schema '$ref' => '#/components/schemas/errorModel'

          let(:benefit_type) { 'compensation' }
          let(:'X-VA-SSN') { '872958715' }
          let(:'X-VA-Receipt-Date') { '1900-01-01' }
          let(:decision_review_type) { 'higher_level_reviews' }

          before do |example|
            VCR.use_cassette('caseflow/higher_level_reviews/bad_date') do
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

      response '502', 'Unknown error' do
        # schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json')))
        # #/errors/0/source is a string 'Appeals Caseflow' instead of an object...

        let(:decision_review_type) { 'higher_level_reviews' }
        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/server_error') do
            submit_request(example.metadata)
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
