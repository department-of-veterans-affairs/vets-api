# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require_relative '../../support/swagger_shared_components'

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength, RSpec/RepeatedDescription
describe 'Supplemental Claims', swagger_doc: 'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json', type: :request do
  let(:apikey) { 'apikey' }

  path '/supplemental_claims' do
    post 'Creates a new Supplemental Claim' do
      tags 'Supplemental Claims'
      operationId 'createSc'
      description 'Submits an appeal of type Supplemental Claim.' \
                  ' This endpoint is the same as submitting [VA form 200995](https://www.vba.va.gov/pubs/forms/VBA-20-0995-ARE.pdf)' \
                  ' via mail or fax directly to the Board of Veterans’ Appeals.'

      security [{ apikey: [] }]

      consumes 'application/json'
      produces 'application/json'

      parameter name: :sc_body, in: :body, schema: { '$ref' => '#/components/schemas/scCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200995.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200995_extra.json')))
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'first' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_middle_initial_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'last' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1900-01-01' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]

      response '200', 'Info about a single Supplemental Claim' do
        let(:sc_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200995.json')))
        end

        schema '$ref' => '#/components/schemas/scCreateResponse'

        before do |example|
          submit_request(example.metadata)
        end

        it 'minimum fields used' do |example|
          assert_response_matches_metadata(example.metadata)
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
      end

      response '200', 'Info about a single Supplemental Claim' do
        let(:sc_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200995_extra.json')))
        end

        schema '$ref' => '#/components/schemas/scCreateResponse'

        before do |example|
          submit_request(example.metadata)
        end

        it 'all fields used' do |example|
          assert_response_matches_metadata(example.metadata)
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
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) do
          request_body = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200995.json')))
          request_body['data']['attributes'].delete('5103NoticeAcknowledged')
          request_body
        end

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 422 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end
    end
  end

  path '/supplemental_claims/{uuid}' do
    get 'Shows a specific Supplemental Claim. (a.k.a. the Show endpoint)' do
      tags 'Supplemental Claims'
      operationId 'showSc'
      description 'Returns all of the data associated with a specific Supplemental Claim.'

      security [{ apikey: [] }]
      produces 'application/json'

      parameter name: :uuid, in: :path, type: :string, description: 'Supplemental Claim UUID'

      response '200', 'Info about a single Supplemental Claim' do
        schema '$ref' => '#/components/schemas/scCreateResponse'

        let(:uuid) { FactoryBot.create(:supplemental_claim).id }

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end

      response '404', 'Supplemental Claim not found' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:uuid) { 'invalid' }

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 404 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end
    end
  end

  path '/supplemental_claims/evidence_submissions/' do
    post 'Get a location for subsequent evidence submission document upload PUT request' do
      tags 'Supplemental Claims'
      operationId 'postSupplementalClaimEvidenceSubmission'
      description <<~DESC
        This is the first step to submitting supporting evidence for an SC.  (See the Evidence Uploads section above for additional information.)
        The Supplemental Claim GUID that is returned when the SC is submitted, is supplied to this endpoint to ensure the SC is in a valid state for sending supporting evidence documents.
      DESC

      parameter name: :sc_uuid, in: :query, type: :string, required: true, description: 'Associated Supplemental Claim UUID'

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '123456789' }

      security [{ apikey: [] }]
      produces 'application/json'

      response '202', 'Accepted. Location generated' do
        let(:sc_uuid) { FactoryBot.create(:supplemental_claim).id }

        schema '$ref' => '#/components/schemas/scEvidenceSubmissionResponse'

        before do |example|
          allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(+'http://some.fakesite.com/path/uuid')
          submit_request(example.metadata)
        end

        it 'returns a 202 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end

      response '400', 'Bad Request' do
        let(:sc_uuid) { nil }

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     properties: {
                       status: {
                         type: 'integer',
                         example: 400
                       },
                       detail: {
                         type: 'string',
                         example: 'Must supply a corresponding SC id in order to submit evidence'
                       }
                     }
                   }
                 }
               }
        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 400 response' do |example|
          # NOOP
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end

      response '404', 'Associated Supplemental Claim not found' do
        let(:sc_uuid) { nil }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 404 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end

      response '422', 'Validation errors' do
        let(:sc_uuid) { FactoryBot.create(:supplemental_claim).id }
        let(:'X-VA-SSN') { '000000000' }

        schema '$ref' => '#/components/schemas/errorModel'

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 422 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end

      response '500', 'Unknown Error' do
        let(:sc_uuid) { nil }

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     properties: {
                       status: {
                         type: 'integer',
                         example: 500
                       },
                       detail: {
                         type: 'string',
                         example: 'An unknown error has occurred.'
                       },
                       code: {
                         type: 'string',
                         example: '151'
                       },
                       title: {
                         type: 'string',
                         example: 'Internal Server Error'
                       }
                     }
                   }
                 },
                 status: {
                   type: 'integer',
                   example: 500
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

  path '/sc_upload_path' do
    put 'Accepts Supplemental Claim Evidence Submission document upload.' do
      tags 'Supplemental Claims'
      operationId 'putSupplementalClaimEvidenceSubmission'

      description File.read(AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'v2', 'put_description.md'))

      parameter name: :'Content-MD5', in: :header, type: :string, description: 'Base64-encoded 128-bit MD5 digest of the message. Use for integrity control.'

      let(:'Content-MD5') { nil }

      response '200', 'Document upload staged' do
        it 'returns a 200 response' do |example|
          # noop
        end
      end

      response '400', 'Document upload failed' do
        produces 'application/xml'

        schema type: :object,
               description: 'Document upload failed',
               xml: { 'name': 'Error' },
               properties: {
                 Code: {
                   type: :string, description: 'Error code', example: 'Bad Digest'
                 },
                 Message: {
                   type: :string, description: 'Error detail',
                   example: 'A client error (InvalidDigest) occurred when calling the PutObject operation - The Content-MD5 you specified was invalid.'
                 },
                 Resource: {
                   type: :string, description: 'Resource description', example: '/example_path_here/6d8433c1-cd55-4c24-affd-f592287a7572.upload'
                 },
                 RequestId: {
                   type: :string, description: 'Identifier for debug purposes'
                 }
               }

        it 'returns a 400 response' do |example|
          # noop
        end
      end
    end
  end

  path '/supplemental_claims/evidence_submissions/{uuid}' do
    get 'Returns all of the data associated with a specific Supplemental Claim Evidence Submission.' do
      tags 'Supplemental Claims'
      operationId 'getSupplementalClaimEvidenceSubmission'
      description 'Returns all of the data associated with a specific Supplemental Claim Evidence Submission.'

      security [{ apikey: [] }]
      produces 'application/json'

      parameter name: :uuid, in: :path, type: :string, description: 'Supplemental Claim UUID Evidence Submission'

      response '200', 'Info about a single Supplemental Claim Evidence Submission.' do
        schema '$ref' => '#/components/schemas/scEvidenceSubmissionResponse'

        let(:uuid) { FactoryBot.create(:sc_evidence_submission).guid }

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end

      response '404', 'Supplemental Claim Evidence Submission not found' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:uuid) { 'invalid' }

        before do |example|
          submit_request(example.metadata)
        end

        it 'returns a 404 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength, RSpec/RepeatedDescription
