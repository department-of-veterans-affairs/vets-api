# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'doc_helpers.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_pdf_downloads.rb')

def openapi_spec
  "modules/appeals_api/app/swagger/higher_level_reviews/v0/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, Layout/LineLength
RSpec.describe 'Higher-Level Reviews', openapi_spec:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  path '/forms/200996' do
    post 'Creates a new Higher-Level Review' do
      description 'Submits an appeal of type Higher-Level Review. ' \
                  'This endpoint is the same as submitting [VA Form 20-0996](https://www.va.gov/decision-reviews/higher-level-review/request-higher-level-review-form-20-0996)' \
                  ' via mail or fax directly to the Board of Veterans’ Appeals.'

      tags 'Higher-Level Reviews'
      operationId 'createHlr'
      security DocHelpers.oauth_security_config(
        AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:POST]
      )
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => { value: FixtureHelpers.fixture_as_json('higher_level_reviews/v0/valid_200996_minimum.json') },
        'all fields used' => { value: FixtureHelpers.fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json') }
      }

      system_scopes = %w[system/HigherLevelReviews.write]

      response '201', 'Higher-Level Review created' do
        let(:hlr_body) { fixture_as_json('higher_level_reviews/v0/valid_200996_minimum.json') }

        schema '$ref' => '#/components/schemas/hlrShow'

        it_behaves_like 'rswag example',
                        desc: 'minimum fields used',
                        response_wrapper: :normalize_appeal_response,
                        extract_desc: true,
                        scopes: system_scopes
      end

      response '201', 'Higher-Level Review created' do
        let(:hlr_body) { fixture_as_json('higher_level_reviews/v0/valid_200996_extra.json') }

        schema '$ref' => '#/components/schemas/hlrShow'

        it_behaves_like 'rswag example',
                        desc: 'all fields used',
                        response_wrapper: :normalize_appeal_response,
                        extract_desc: true,
                        scopes: system_scopes
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) { nil }

        it_behaves_like 'rswag example',
                        desc: 'Body is not a JSON object',
                        extract_desc: true,
                        scopes: system_scopes
      end

      response '403', 'Forbidden attempt using a veteran-scoped OAuth token to create a Higher-Level Review for another veteran' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          fixture_as_json('higher_level_reviews/v0/valid_200996.json').tap do |data|
            data['data']['attributes']['veteran']['icn'] = '1234567890V987654'
          end
        end

        it_behaves_like 'rswag example', scopes: %w[veteran/HigherLevelReviews.write]
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) do
          request_body = fixture_as_json('higher_level_reviews/v0/valid_200996.json')
          request_body['data']['attributes'].delete('informalConference')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'Returns a 422 response', scopes: system_scopes
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/forms/200996/{id}' do
    get 'Show a specific Higher-Level Review' do
      description 'Returns basic data associated with a specific Higher-Level Review.'
      tags 'Higher-Level Reviews'
      operationId 'showHlr'
      security DocHelpers.oauth_security_config(AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES[:GET])
      produces 'application/json'

      parameter name: :id,
                in: :path,
                description: 'Higher-Level Review ID',
                schema: { type: :string, format: :uuid },
                example: '44e08764-6008-46e8-a95e-eb21951a5b68'

      veteran_scopes = %w[veteran/HigherLevelReviews.read]

      response '200', 'Success' do
        schema '$ref' => '#/components/schemas/hlrShow'

        let(:id) { create(:minimal_higher_level_review_v0).id }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_appeal_response,
                                         scopes: veteran_scopes
      end

      response '403', 'Forbidden access with a veteran-scoped OAuth token to an unowned Higher-Level Review' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:id) { create(:minimal_higher_level_review_v0, veteran_icn: '1234567890V123456').id }

        it_behaves_like 'rswag example',
                        desc: 'with a veteran-scoped OAuth token for a Veteran who does not own the Higher-Level Review',
                        scopes: veteran_scopes
      end

      response '404', 'Higher-Level Review not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:id) { '11111111-1111-1111-1111-111111111111' }

        it_behaves_like 'rswag example',
                        desc: 'returns a 404 response',
                        scopes: veteran_scopes
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

      examples.each_value do |v|
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

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'hlr_validate.json')))

        it_behaves_like 'rswag example',
                        desc: 'all fields used',
                        extract_desc: true,
                        scopes:
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:hlr_body) { nil }

        it_behaves_like 'rswag example',
                        desc: 'Not JSON object',
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

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
