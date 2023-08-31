# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'doc_helpers.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_pdf_downloads.rb')

def swagger_doc
  "modules/appeals_api/app/swagger/higher_level_reviews/v0/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength
RSpec.describe 'Higher-Level Reviews', swagger_doc:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  path '/forms/200996' do
    post 'Creates a new Higher-Level Review' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:POST]
      description 'Submits an appeal of type Higher Level Review. ' \
                  'This endpoint is the same as submitting [VA Form 20-0996](https://www.va.gov/decision-reviews/higher-level-review/request-higher-level-review-form-20-0996)' \
                  ' via mail or fax directly to the Board of Veterans’ Appeals.'

      tags 'Higher-Level Reviews'
      operationId 'createHlr'
      security DocHelpers.oauth_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => { value: FixtureHelpers.fixture_as_json('higher_level_reviews/v0/valid_200996_minimum.json') },
        'all fields used' => { value: FixtureHelpers.fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json') }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge({ required: true })
      let(:'X-VA-ICN') { '1234567890V123456' }

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

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) { fixture_as_json('higher_level_reviews/v0/valid_200996_minimum.json') }

        schema '$ref' => '#/components/schemas/hlrShow'

        it_behaves_like 'rswag example',
                        desc: 'minimum fields used',
                        response_wrapper: :normalize_appeal_response,
                        extract_desc: true,
                        scopes:
      end

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) { fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json') }
        let(:'X-VA-NonVeteranClaimant-SSN') { '999999999' }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema '$ref' => '#/components/schemas/hlrShow'

        it_behaves_like 'rswag example',
                        desc: 'all fields used',
                        response_wrapper: :normalize_appeal_response,
                        extract_desc: true,
                        scopes:
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = fixture_as_json('higher_level_reviews/v0/valid_200996.json')
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'Returns a 422 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/forms/200996/{id}' do
    get 'Shows a specific Higher-Level Review. (a.k.a. the Show endpoint)' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET]
      description 'Returns all of the data associated with a specific Higher-Level Review.'
      tags 'Higher-Level Reviews'
      operationId 'showHlr'
      security DocHelpers.oauth_security_config(scopes)
      produces 'application/json'

      parameter name: :id,
                in: :path,
                description: 'Higher-Level Review ID',
                schema: { type: :string, format: :uuid },
                example: '44e08764-6008-46e8-a95e-eb21951a5b68'

      response '200', 'Info about a single Higher-Level Review' do
        schema '$ref' => '#/components/schemas/hlrShow'

        let(:id) { FactoryBot.create(:minimal_higher_level_review_v2).id }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_appeal_response,
                                         scopes:
      end

      response '404', 'Higher-Level Review not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:id) { 'invalid' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/forms/200996/{id}/download' do
    get 'Download a watermarked copy of a submitted Higher-Level Review' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET]
      tags 'Higher-Level Reviews'
      operationId 'downloadHlr'
      security DocHelpers.oauth_security_config(scopes)

      include_examples 'PDF download docs', {
        factory: :higher_level_review_v0,
        appeal_type_display_name: 'Higher-Level Review',
        scopes:
      }
    end
  end

  path '/schemas/{schema_type}' do
    get 'Gets JSON schema related to Higher-Level Review.' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET]
      tags 'Higher-Level Reviews'
      operationId 'hlrSchema'
      description 'Returns the [JSON Schema](https://json-schema.org) related to the `POST /forms/200996` endpoint'
      security DocHelpers.oauth_security_config(scopes)
      produces 'application/json'

      examples = {
        '200996': { value: '200996' },
        address: { value: 'address' },
        nonBlankString: { value: 'nonBlankString' },
        phone: { value: 'phone' },
        timezone: { value: 'timezone' }
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

  path '/forms/200996/validate' do
    post 'Validates a POST request body against the JSON schema.' do
      scopes = AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:POST]
      tags 'Higher-Level Reviews'
      operationId 'hlrValidate'
      description 'Like the POST /higher_level_reviews, but only does the validations <b>—does not submit anything.</b>'
      security DocHelpers.oauth_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => { value: FixtureHelpers.fixture_as_json('higher_level_reviews/v0/valid_200996_minimum.json') },
        'all fields used' => { value: FixtureHelpers.fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json') }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge({ required: true })
      let(:'X-VA-ICN') { '1234567890V123456' }

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

      response '200', 'Valid' do
        let(:hlr_body) { fixture_as_json('higher_level_reviews/v0/valid_200996_minimum.json') }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        it_behaves_like 'rswag example',
                        desc: 'minimum fields used',
                        extract_desc: true,
                        scopes:
      end

      response '200', 'Valid' do
        let(:hlr_body) { fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json') }
        let(:'X-VA-NonVeteranClaimant-SSN') { '999999999' }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        it_behaves_like 'rswag example',
                        desc: 'all fields used',
                        extract_desc: true,
                        scopes:
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json')
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        it_behaves_like 'rswag example',
                        desc: 'Violates JSON schema',
                        extract_desc: true,
                        scopes:
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) { nil }

        it_behaves_like 'rswag example',
                        desc: 'Not JSON object',
                        extract_desc: true,
                        scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
