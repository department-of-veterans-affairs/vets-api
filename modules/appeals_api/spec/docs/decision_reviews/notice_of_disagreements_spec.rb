# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength
describe 'Notice of Disagreements', swagger_doc: DocHelpers.output_json_path, type: :request do
  include DocHelpers
  if DocHelpers.decision_reviews?
    let(:apikey) { 'apikey' }
  else
    let(:Authorization) { 'Bearer TEST_TOKEN' }
  end

  p = DocHelpers.decision_reviews? ? '/notice_of_disagreements' : '/forms/10182'
  path p do
    post 'Creates a new Notice of Disagreement' do
      scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST]
      tags 'Notice of Disagreements'
      operationId 'createNod'
      description 'Submits an appeal of type Notice of Disagreement.' \
                  ' This endpoint is the same as submitting [VA Form 10182](https://www.va.gov/vaforms/va/pdf/VA10182.pdf)' \
                  ' via mail or fax directly to the Board of Veterans’ Appeals.'

      security DocHelpers.decision_reviews_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :nod_body, in: :body, schema: { '$ref' => '#/components/schemas/nodCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_minimum.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_extra.json')))
        }
      }

      file_number_header_params = AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      file_number_header_params[:required] = true

      parameter file_number_header_params
      let(:'X-VA-File-Number') { '987654321' }

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

      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_first_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_middle_initial_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_last_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_birth_date_header]

      if DocHelpers.decision_reviews?
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]
      end

      response '200', 'Info about a single Notice of Disagreement' do
        let(:nod_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_minimum.json')))
        end

        schema '$ref' => '#/components/schemas/nodCreateResponse'

        before do |example|
          with_rswag_auth(scopes) do
            submit_request(example.metadata)
          end
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
                  value: normalize_appeal_response(response)
                }
              }
            }
          }
        end
      end

      response '200', 'Info about a single Notice of Disagreement' do
        let(:nod_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_extra.json')))
        end

        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }
        let(:'X-VA-NonVeteranClaimant-Birth-Date') { '1921-08-08' }

        schema '$ref' => '#/components/schemas/nodCreateResponse'

        it_behaves_like 'rswag example', desc: 'all fields used',
                                         response_wrapper: :normalize_appeal_response,
                                         extract_desc: true,
                                         scopes:
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:nod_body) do
          request_body = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182.json')))
          request_body['data']['attributes'].delete('boardReviewOption')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'returns a 422 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  p = DocHelpers.decision_reviews? ? '/notice_of_disagreements/{uuid}' : '/forms/10182/{uuid}'
  path p do
    get 'Shows a specific Notice of Disagreement. (a.k.a. the Show endpoint)' do
      scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:GET]
      tags 'Notice of Disagreements'
      operationId 'showNod'
      description 'Returns all of the data associated with a specific Notice of Disagreement.'

      security DocHelpers.decision_reviews_security_config(scopes)
      produces 'application/json'

      parameter name: :uuid,
                in: :path,
                type: :string,
                description: 'Notice of Disagreement UUID',
                example: '02bbbe56-443c-42fa-aaf2-ef6200a6eddd'

      response '200', 'Info about a single Notice of Disagreement' do
        schema '$ref' => '#/components/schemas/nodShowResponse'

        let(:uuid) { FactoryBot.create(:notice_of_disagreement_v2).id }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_appeal_response,
                                         scopes:
      end

      response '404', 'Notice of Disagreement not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:uuid) { 'invalid' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  if DocHelpers.decision_reviews?
    path '/notice_of_disagreements/schema' do
      get 'Gets the Notice of Disagreement JSON Schema.' do
        tags 'Notice of Disagreements'
        operationId 'nodSchema'
        description 'Returns the [JSON Schema](https://json-schema.org/) for the `POST /notice_of_disagreements` endpoint.'
        security DocHelpers.decision_reviews_security_config
        produces 'application/json'

        response '200', 'the JSON Schema for POST /notice_of_disagreements' do
          it_behaves_like 'rswag example', desc: 'returns a 200 response', response_wrapper: :raw_body
        end

        it_behaves_like 'rswag 500 response'
      end
    end
  else
    path '/schemas/{schema_type}' do
      get 'Gets the Notice of Disagreement JSON Schema.' do
        scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:GET]
        tags 'Notice of Disagreements'
        operationId 'nodSchema'
        description 'Returns the [JSON Schema](https://json-schema.org/) for the `POST /forms/10182` endpoint.'
        security DocHelpers.decision_reviews_security_config(scopes)
        produces 'application/json'

        examples = {
          '10182': { value: '10182' },
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

  p = DocHelpers.decision_reviews? ? '/notice_of_disagreements/validate' : '/forms/10182/validate'
  path p do
    post 'Validates a POST request body against the JSON schema.' do
      scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST]
      desc_path = DocHelpers.decision_reviews? ? '/notice_of_disagreements' : '/forms/10182'

      tags 'Notice of Disagreements'
      operationId 'nodValidate'
      description "Like the POST #{desc_path}, but only does the validations <b>—does not submit anything.</b>"
      security DocHelpers.decision_reviews_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :nod_body, in: :body, schema: { '$ref' => '#/components/schemas/nodCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_minimum.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_extra.json')))
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      let(:'X-VA-File-Number') { '987654321' }

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

      if DocHelpers.decision_reviews?
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
        parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]
      end

      response '200', 'Valid' do
        let(:nod_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_minimum.json')))
        end

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'nod_validate.json')))

        it_behaves_like 'rswag example', desc: 'minimum fields used', extract_desc: true, scopes:
      end

      response '200', 'Info about a single Notice of Disagreement' do
        let(:nod_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182.json')))
        end

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'nod_validate.json')))

        it_behaves_like 'rswag example', desc: 'all fields used', extract_desc: true, scopes:
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:nod_body) do
          request_body = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_10182_minimum.json')))
          request_body['data']['attributes'].delete('boardReviewOption')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'Violates JSON schema', extract_desc: true, scopes:
      end

      response '422', 'Error' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:nod_body) do
          nil
        end

        it_behaves_like 'rswag example', desc: 'Not JSON object', extract_desc: true, scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  p = DocHelpers.decision_reviews? ? '/notice_of_disagreements/evidence_submissions' : '/evidence-submissions'
  path p do
    post 'Get a location for subsequent evidence submission document upload PUT request' do
      scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST]
      tags 'Notice of Disagreements'
      operationId 'postNoticeOfDisagreementEvidenceSubmission'
      description <<~DESC
        This is the first step to submitting supporting evidence for an NOD.  (See the Evidence Uploads section above for additional information.)
        The Notice of Disagreement GUID that is returned when the NOD is submitted, is supplied to this endpoint to ensure the NOD is in a valid state for sending supporting evidence documents.  Only NODs that selected the Evidence Submission lane are allowed to submit evidence documents up to 90 days after the NOD is received by VA.
      DESC

      parameter name: :nod_uuid,
                in: :query,
                type: :string,
                required: true,
                description: 'Associated Notice of Disagreement UUID',
                example: '9dbc8f83-a778-417e-9f8b-a9a36d710f70'

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      let(:'X-VA-File-Number') { '987654321' }

      security DocHelpers.decision_reviews_security_config(scopes)
      produces 'application/json'

      response '202', 'Accepted. Location generated' do
        let(:nod_uuid) { FactoryBot.create(:notice_of_disagreement_v2, :board_review_evidence_submission).id }

        schema '$ref' => '#/components/schemas/nodEvidenceSubmissionResponse'

        before do
          allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(+'http://some.fakesite.com/path/uuid')
        end

        it_behaves_like 'rswag example', desc: 'returns a 202 response',
                                         response_wrapper: :normalize_evidence_submission_response,
                                         scopes:
      end

      response '400', 'Bad Request' do
        let(:nod_uuid) { nil }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 400 response', skip_match: true, scopes:
      end

      response '404', 'Associated Notice of Disagreement not found' do
        let(:nod_uuid) { '101010101010101010101010' }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      response '422', 'Validation errors' do
        let(:nod_uuid) { FactoryBot.create(:notice_of_disagreement_v2, :board_review_direct_review).id }
        let(:'X-VA-File-Number') { '987654321' }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 422 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/nod_upload_path' do
    put 'Accepts Notice of Disagreement Evidence Submission document upload.' do
      scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST]
      tags 'Notice of Disagreements'
      operationId 'putNoticeOfDisagreementEvidenceSubmission'
      description File.read(DocHelpers.output_directory_file_path('put_description.md'))
      security DocHelpers.decision_reviews_security_config(scopes)

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

      it_behaves_like 'rswag 500 response'
    end
  end

  p = DocHelpers.decision_reviews? ? '/notice_of_disagreements/evidence_submissions/{uuid}' : '/evidence-submissions/{uuid}'
  path p do
    get 'Returns all of the data associated with a specific Notice of Disagreement Evidence Submission.' do
      scopes = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:GET]
      tags 'Notice of Disagreements'
      operationId 'getNoticeOfDisagreementEvidenceSubmission'
      description 'Returns all of the data associated with a specific Notice of Disagreement Evidence Submission.'

      security DocHelpers.decision_reviews_security_config(scopes)
      produces 'application/json'

      parameter name: :uuid,
                in: :path,
                type: :string,
                description: 'Notice of Disagreement UUID Evidence Submission',
                example: 'b77404cf-ef08-45e4-8201-d5b7622f63df'

      response '200', 'Info about a single Notice of Disagreement Evidence Submission.' do
        schema '$ref' => '#/components/schemas/nodEvidenceSubmissionResponse'

        let(:uuid) { FactoryBot.create(:evidence_submission).guid }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_evidence_submission_response,
                                         scopes:
      end

      response '404', 'Notice of Disagreement Evidence Submission not found' do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:uuid) { 'invalid' }
        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, Layout/LineLength
