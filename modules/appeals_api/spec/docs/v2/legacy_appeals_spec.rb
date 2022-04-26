# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength
describe 'Legacy Appeals', swagger_doc: "modules/appeals_api/app/swagger/appeals_api/v2/swagger#{DocHelpers.doc_suffix}.json", type: :request do
  include DocHelpers
  let(:apikey) { 'apikey' }

  path '/legacy_appeals' do
    get 'Returns eligible appeals in the legacy process for a Veteran.' do
      tags 'Legacy Appeals'
      operationId 'getLegacyAppeals'
      security [{ apikey: [] }]
      consumes 'application/json'
      produces 'application/json'
      description = 'Returns eligible legacy appeals for a Veteran. A legacy appeal is eligible if a statement of ' \
                    'the case (SOC)  or supplemental statement of the case (SSOC) has been declared, and if the ' \
                    'date of declaration is within the last 60 days.'
      description description

      ssn_override = { required: false,
                       description: 'Either X-VA-SSN or X-VA-File-Number is required. Example X-VA-SSN: 123456789' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header].merge(ssn_override)
      file_num_override = {
        description: 'Either X-VA-SSN or X-VA-File-Number is required. Example X-VA-File-Number: 123456789'
      }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header].merge(file_num_override)

      response '200', 'Returns eligible legacy appeals for a Veteran' do
        let(:'X-VA-SSN') { '123456789' }

        schema '$ref' => '#/components/schemas/legacyAppeals'

        before do |example|
          VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
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

      response '404', 'Veteran record not found' do
        let(:'X-VA-SSN') { '234840293' }

        schema JSON.parse(
          File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json'))
        )

        before do |example|
          VCR.use_cassette('caseflow/legacy_appeals_no_veteran_record') do
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

      response '422', 'Header Errors' do
        context 'when X-VA-SSN and X-VA-File-Number are missing' do
          let(:'X-VA-SSN') { nil }
          let(:'X-VA-FILE-NUMBER') { nil }

          schema '$ref' => '#/components/schemas/errorModel'

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

        context 'when ssn formatted incorrectly' do
          let(:'X-VA-SSN') { '12n-~89' }

          schema '$ref' => '#/components/schemas/errorModel'

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
      end

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
          submit_request(example.metadata)
        end

        it 'returns a 500 response' do |example|
          # NOOP
        end
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength
