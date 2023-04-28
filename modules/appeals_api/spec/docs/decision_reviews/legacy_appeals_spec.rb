# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample
describe 'Legacy Appeals', swagger_doc: DocHelpers.output_json_path, type: :request do
  include DocHelpers
  if DocHelpers.decision_reviews?
    let(:apikey) { 'apikey' }
  else
    let(:Authorization) { 'Bearer TEST_TOKEN' }
  end

  path DocHelpers.decision_reviews? ? '/legacy_appeals' : '/legacy-appeals' do
    get 'Returns eligible appeals in the legacy process for a Veteran.' do
      scopes = AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]
      tags 'Legacy Appeals'
      operationId 'getLegacyAppeals'
      security DocHelpers.security_config(scopes)
      consumes 'application/json'
      produces 'application/json'
      description = 'Returns eligible legacy appeals for a Veteran. A legacy appeal is eligible if a statement of ' \
                    'the case (SOC)  or supplemental statement of the case (SSOC) has been declared, and if the ' \
                    'date of declaration is within the last 60 days.'
      description description

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header].merge(
        {
          required: false,
          description: 'Either X-VA-SSN or X-VA-File-Number is required. Example X-VA-SSN: 123456789'
        }
      )
      let(:'X-VA-SSN') { '123456789' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header].merge(
        {
          description: 'Either X-VA-SSN or X-VA-File-Number is required. Example X-VA-File-Number: 123456789'
        }
      )
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge(
        {
          required: !DocHelpers.decision_reviews?
        }
      )
      let(:'X-VA-ICN') { '1234567890V123456' } unless DocHelpers.decision_reviews?

      response '200', 'Returns eligible legacy appeals for a Veteran' do
        schema '$ref' => '#/components/schemas/legacyAppeals'

        before do |example|
          VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
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

      response '404', 'Veteran record not found' do
        let(:'X-VA-SSN') { '234840293' }

        schema '$ref' => '#/components/schemas/errorModel'

        before do |example|
          VCR.use_cassette('caseflow/legacy_appeals_no_veteran_record') do
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

      response '422', 'Header Errors' do
        context 'when X-VA-SSN and X-VA-File-Number are missing' do
          let(:'X-VA-SSN') { nil }
          let(:'X-VA-File-Number') { nil }

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

        unless DocHelpers.decision_reviews?
          context 'when X-VA-ICN is missing' do
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

        context 'when SSN formatted incorrectly' do
          let(:'X-VA-SSN') { '12n-~89' }

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

        context 'when ICN formatted incorrectly' do
          let(:'X-VA-SSN') { '123456789' }
          let(:'X-VA-ICN') { '12345' }

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

      it_behaves_like 'rswag 500 response'

      response '502', 'Unknown Error' do
        let(:'X-VA-SSN') { nil }

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

        it 'returns a 502 response' do |example|
          # NOOP
        end
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample
