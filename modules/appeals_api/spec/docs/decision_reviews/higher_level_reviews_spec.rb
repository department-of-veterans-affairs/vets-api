# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_pdf_downloads.rb')

def swagger_doc
  "modules/appeals_api/app/swagger/decision_reviews/v2/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength
describe 'Higher-Level Reviews', swagger_doc:, type: :request do
  include DocHelpers
  include FixtureHelpers
  let(:apikey) { 'apikey' }

  path '/higher_level_reviews' do
    post 'Creates a new Higher-Level Review' do
      description 'Submits an appeal of type Higher Level Review. ' \
                  'This endpoint is the same as submitting [VA Form 20-0996](https://www.va.gov/decision-reviews/higher-level-review/request-higher-level-review-form-20-0996)' \
                  ' via mail or fax directly to the Board of Veterans’ Appeals.'

      tags 'Higher-Level Reviews'
      operationId 'createHlr'
      security DocHelpers.decision_reviews_security_config
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200996_minimum.json')
        },
        'all fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200996_extra.json')
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header]
      let(:'X-VA-ICN') { '1234567890V987654' }

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

      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) { fixture_as_json('decision_reviews/v2/valid_200996_minimum.json') }

        schema '$ref' => '#/components/schemas/hlrShow'

        it_behaves_like 'rswag example',
                        desc: 'minimum fields used',
                        response_wrapper: :normalize_appeal_response,
                        extract_desc: true
      end

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) { fixture_as_json('decision_reviews/v2/valid_200996_extra.json') }
        let(:'X-VA-NonVeteranClaimant-SSN') { '999999999' }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema '$ref' => '#/components/schemas/hlrShow'

        it_behaves_like 'rswag example',
                        desc: 'all fields used',
                        response_wrapper: :normalize_appeal_response,
                        extract_desc: true
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = fixture_as_json('decision_reviews/v2/valid_200996.json')
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'Returns a 422 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/higher_level_reviews/{uuid}' do
    get 'Shows a specific Higher-Level Review. (a.k.a. the Show endpoint)' do
      description 'Returns all of the data associated with a specific Higher-Level Review.'
      tags 'Higher-Level Reviews'
      operationId 'showHlr'
      security DocHelpers.decision_reviews_security_config
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
                                         response_wrapper: :normalize_appeal_response
      end

      response '404', 'Higher-Level Review not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:uuid) { 'invalid' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  if ENV['RSWAG_ENV'] == 'dev'
    path '/higher_level_reviews/{uuid}/download' do
      get 'Download a watermarked copy of a submitted Higher-Level Review' do
        tags 'Higher-Level Reviews'
        operationId 'downloadHlr'
        security DocHelpers.decision_reviews_security_config

        include_examples 'decision reviews PDF download docs', {
          factory: :extra_higher_level_review_v2,
          appeal_type_display_name: 'Higher-Level Review'
        }
      end
    end
  end

  path '/higher_level_reviews/contestable_issues/{benefit_type}' do
    get 'Returns all contestable issues for a specific veteran.' do
      tags 'Higher-Level Reviews'
      operationId 'hlrContestableIssues'
      description = 'Returns all issues associated with a Veteran that have been decided by a ' \
                    'Higher-Level Review as of the receiptDate and bound by benefitType. Not all issues returned are guaranteed '\
                    'to be eligible for appeal. Associate these results when creating a new Higher-Level Review.'
      description description
      security DocHelpers.decision_reviews_security_config
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

        it_behaves_like 'rswag example',
                        cassette: 'caseflow/higher_level_reviews/contestable_issues',
                        desc: 'Returns a 200 response'
      end

      response '404', 'Veteran not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '000000000' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        it_behaves_like 'rswag example',
                        cassette: 'caseflow/higher_level_reviews/not_found',
                        desc: 'Returns a 404 response'
      end

      response '422', 'Bad receipt date' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '1900-01-01' }

        it_behaves_like 'rswag example',
                        cassette: 'caseflow/higher_level_reviews/bad_date',
                        desc: 'Returns a 422 response'
      end

      it_behaves_like 'rswag 500 response'

      response '502', 'Unknown error' do
        # schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json')))
        # #/errors/0/source is a string 'Appeals Caseflow' instead of an object...

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        it_behaves_like 'rswag example',
                        cassette: 'caseflow/higher_level_reviews/server_error',
                        desc: 'Returns a 422 response'
      end
    end
  end

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

  path '/higher_level_reviews/validate' do
    post 'Validates a POST request body against the JSON schema.' do
      tags 'Higher-Level Reviews'
      operationId 'hlrValidate'
      description 'Like the POST /higher_level_reviews, but only does the validations <b>—does not submit anything.</b>'
      security DocHelpers.decision_reviews_security_config
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200996_minimum.json')
        },
        'all fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200996_extra.json')
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header]
      let(:'X-VA-ICN') { '1234567890V987654' }

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

      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]

      response '200', 'Valid' do
        let(:hlr_body) { fixture_as_json('decision_reviews/v2/valid_200996_minimum.json') }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        it_behaves_like 'rswag example',
                        desc: 'minimum fields used',
                        extract_desc: true
      end

      response '200', 'Valid' do
        let(:hlr_body) { fixture_as_json('decision_reviews/v2/valid_200996_extra.json') }
        let(:'X-VA-NonVeteranClaimant-SSN') { '999999999' }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        it_behaves_like 'rswag example',
                        desc: 'all fields used',
                        extract_desc: true
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = fixture_as_json('decision_reviews/v2/valid_200996_extra.json')
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        it_behaves_like 'rswag example',
                        desc: 'Violates JSON schema',
                        extract_desc: true
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          nil
        end

        it_behaves_like 'rswag example',
                        desc: 'Not JSON object',
                        extract_desc: true
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
