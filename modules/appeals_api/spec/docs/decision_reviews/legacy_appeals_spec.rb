# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName
describe 'Legacy Appeals', swagger_doc: DocHelpers.output_json_path, type: :request do
  include DocHelpers
  let(:apikey) { 'apikey' }

  path '/legacy_appeals' do
    get 'Returns eligible appeals in the legacy process for a Veteran.' do
      tags 'Legacy Appeals'
      operationId 'getLegacyAppeals'
      security DocHelpers.decision_reviews_security_config
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
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header]

      response '200', 'Returns eligible legacy appeals for a Veteran' do
        schema '$ref' => '#/components/schemas/legacyAppeals'

        it_behaves_like 'rswag example',
                        desc: 'returns a 200 response',
                        cassette: 'caseflow/legacy_appeals_get_by_ssn'
      end

      response '404', 'Veteran record not found' do
        let(:'X-VA-SSN') { '234840293' }

        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example',
                        desc: 'returns a 404 response',
                        cassette: 'caseflow/legacy_appeals_no_veteran_record'
      end

      response '422', 'Header Errors' do
        schema '$ref' => '#/components/schemas/errorModel'

        describe 'X-VA-SSN and X-VA-File-Number both missing' do
          let(:'X-VA-SSN') { nil }
          let(:'X-VA-File-Number') { nil }

          it_behaves_like 'rswag example',
                          desc: 'when X-VA-SSN and X-VA-File-Number are missing',
                          extract_desc: true
        end

        describe 'malformed SSN' do
          let(:'X-VA-SSN') { '12n-~89' }

          it_behaves_like 'rswag example',
                          desc: 'when SSN formatted incorrectly',
                          extract_desc: true
        end

        context 'malformed ICN' do
          let(:'X-VA-ICN') { '12345' }

          it_behaves_like 'rswag example',
                          desc: 'when ICN formatted incorrectly',
                          extract_desc: true
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
          submit_request(example.metadata)
        end

        it 'returns a 502 response' do |_example|
          # NOOP
        end
      end
    end
  end
end
# rubocop:enable RSpec/VariableName
