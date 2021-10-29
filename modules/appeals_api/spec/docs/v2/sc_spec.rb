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
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength, RSpec/RepeatedDescription
