# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, RSpec/RepeatedDescription, Layout/LineLength
describe 'Higher-Level Reviews', swagger_doc: DocHelpers.output_json_path, type: :request do
  include DocHelpers
  if DocHelpers.decision_reviews?
    let(:apikey) { 'apikey' }
  else
    let(:Authorization) { 'Bearer TEST_TOKEN' }
  end

  p = DocHelpers.decision_reviews? ? '/higher_level_reviews' : '/forms/200996'
  path p do
    post 'Creates a new Higher-Level Review' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:POST]
      description 'Submits an appeal of type Higher Level Review. ' \
                  'This endpoint is the same as submitting [VA Form 20-0996](https://www.va.gov/decision-reviews/higher-level-review/request-higher-level-review-form-20-0996)' \
                  ' via mail or fax directly to the Board of Veterans’ Appeals.'

      tags 'Higher-Level Reviews'
      operationId 'createHlr'
      security DocHelpers.decision_reviews_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_minimum.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_extra.json')))
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge(
        {
          required: !DocHelpers.decision_reviews?
        }
      )
      let(:'X-VA-ICN') { '1234567890V123456' } unless DocHelpers.decision_reviews?

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'first' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_middle_initial_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'last' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1900-01-01' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_insurance_policy_number_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_first_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_middle_initial_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_last_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_ssn_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_birth_date_header]

      if DocHelpers.decision_reviews?
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]
      end

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_minimum.json')))
        end

        schema '$ref' => '#/components/schemas/hlrShow'

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: normalize_appeal_response(response)
                }
              }
            }
          }
        end

        it 'minimum fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_extra.json')))
        end
        let(:'X-VA-NonVeteranClaimant-SSN') { '999999999' }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema '$ref' => '#/components/schemas/hlrShow'

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: normalize_appeal_response(response)
                }
              }
            }
          }
        end

        it 'all fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996.json')))
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        before do |example|
          with_rswag_auth(scopes) do
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

        it 'returns a 422 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  p = DocHelpers.decision_reviews? ? '/higher_level_reviews/{uuid}' : '/forms/200996/{uuid}'
  path p do
    get 'Shows a specific Higher-Level Review. (a.k.a. the Show endpoint)' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET]
      description 'Returns all of the data associated with a specific Higher-Level Review.'
      tags 'Higher-Level Reviews'
      operationId 'showHlr'
      security DocHelpers.decision_reviews_security_config(scopes)
      produces 'application/json'

      parameter name: :uuid,
                in: :path,
                type: :string,
                description: 'Higher-Level Review UUID',
                example: '44e08764-6008-46e8-a95e-eb21951a5b68'

      response '200', 'Info about a single Higher-Level Review' do
        schema '$ref' => '#/components/schemas/hlrShow'

        let(:uuid) { FactoryBot.create(:minimal_higher_level_review_v2).id }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_appeal_response,
                                         scopes:
      end

      response '404', 'Higher-Level Review not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:uuid) { 'invalid' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  if DocHelpers.decision_reviews?
    path '/higher_level_reviews/contestable_issues/{benefit_type}' do
      get 'Returns all contestable issues for a specific veteran.' do
        scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET]
        tags 'Higher-Level Reviews'
        operationId 'hlrContestableIssues'
        description = 'Returns all issues associated with a Veteran that have been decided by a ' \
                      'Higher-Level Review as of the receiptDate and bound by benefitType. Not all issues returned are guaranteed '\
                      'to be eligible for appeal. Associate these results when creating a new Higher-Level Review.'
        description description
        security DocHelpers.decision_reviews_security_config(scopes)
        produces 'application/json'

        parameter name: :benefit_type, in: :path, type: :string,
                  description: 'benefit type - Available values: compensation'

        ssn_override = { required: false, description: 'Either X-VA-SSN or X-VA-File-Number is required' }
        parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header].merge(ssn_override)
        file_num_override = { description: 'Either X-VA-SSN or X-VA-File-Number is required' }
        parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header].merge(file_num_override)
        parameter AppealsApi::SwaggerSharedComponents.header_params[:va_receipt_date]
        parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header]

        response '200', 'JSON:API response returning all contestable issues for a specific veteran.' do
          schema '$ref' => '#/components/schemas/contestableIssues'

          let(:benefit_type) { 'compensation' }
          let(:'X-VA-SSN') { '872958715' }
          let(:'X-VA-Receipt-Date') { '2019-12-01' }

          before do |example|
            VCR.use_cassette('caseflow/higher_level_reviews/contestable_issues') do
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

        response '422', 'Bad receipt date' do
          schema '$ref' => '#/components/schemas/errorModel'

          let(:benefit_type) { 'compensation' }
          let(:'X-VA-SSN') { '872958715' }
          let(:'X-VA-Receipt-Date') { '1900-01-01' }

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
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end

        it_behaves_like 'rswag 500 response'

        response '502', 'Unknown error' do
          # schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json')))
          # #/errors/0/source is a string 'Appeals Caseflow' instead of an object...

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

  if DocHelpers.decision_reviews?
    path '/higher_level_reviews/schema' do
      get 'Gets the Higher-Level Review JSON Schema.' do
        tags 'Higher-Level Reviews'
        operationId 'hlrSchema'
        description 'Returns the [JSON Schema](https://json-schema.org/) for the `POST /higher_level_reviews` endpoint.'
        security DocHelpers.decision_reviews_security_config
        produces 'application/json'

        response '200', 'the JSON Schema for POST /higher_level_reviews' do
          it_behaves_like 'rswag example', desc: 'returns a 200 response', response_wrapper: :raw_body
        end

        it_behaves_like 'rswag 500 response'
      end
    end
  else
    path '/schemas/{schema_type}' do
      get 'Gets JSON schema related to Higher-Level Review.' do
        scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET]
        tags 'Higher-Level Reviews'
        operationId 'hlrSchema'
        description 'Returns the [JSON Schema](https://json-schema.org) related to the `POST /forms/200996` endpoint'
        security DocHelpers.decision_reviews_security_config(scopes)
        produces 'application/json'

        examples = {
          '200996': { value: '200996' },
          'address': { value: 'address' },
          'non_blank_string': { value: 'non_blank_string' },
          'phone': { value: 'phone' },
          'timezone': { value: 'timezone' }
        }

        parameter(name: :schema_type,
                  in: :path,
                  type: :string,
                  description: "Schema type. Can be: `#{examples.keys.join('`, `')}`",
                  required: true,
                  examples:)

        examples.each do |_, v|
          response '200', 'The JSON schema for the given `schema_type` parameter' do
            let(:schema_type) { v[:value] }
            it_behaves_like 'rswag example', desc: v[:value], extract_desc: true, scopes:
          end
        end

        response '404', '`schema_type` not found' do
          schema '$ref' => '#/components/schemas/errorModel'
          let(:schema_type) { 'invalid_schema_type' }
          it_behaves_like 'rswag example', desc: 'schema type not found', scopes:
        end

        it_behaves_like 'rswag 500 response'
      end
    end
  end

  p = DocHelpers.decision_reviews? ? '/higher_level_reviews/validate' : '/forms/200996/validate'
  path p do
    post 'Validates a POST request body against the JSON schema.' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:POST]
      tags 'Higher-Level Reviews'
      operationId 'hlrValidate'
      description 'Like the POST /higher_level_reviews, but only does the validations <b>—does not submit anything.</b>'
      security DocHelpers.decision_reviews_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_minimum.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_extra.json')))
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge(
        {
          required: !DocHelpers.decision_reviews?
        }
      )
      let(:'X-VA-ICN') { '1234567890V123456' } unless DocHelpers.decision_reviews?

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'first' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_middle_initial_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'last' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1900-01-01' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_insurance_policy_number_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_first_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_middle_initial_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_last_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_ssn_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_birth_date_header]

      if DocHelpers.decision_reviews?
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]
      end

      response '200', 'Valid' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_minimum.json')))
        end

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end

        it 'minimum fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '200', 'Valid' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_extra.json')))
        end
        let(:'X-VA-NonVeteranClaimant-SSN') { '999999999' }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end

        it 'all fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_extra.json')))
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end

        it 'Violates JSON schema' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          nil
        end

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end

        it 'Not JSON object' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, RSpec/RepeatedDescription, Layout/LineLength
