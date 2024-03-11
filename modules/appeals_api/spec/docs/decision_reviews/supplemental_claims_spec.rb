# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_pdf_downloads.rb')

def openapi_spec
  "modules/appeals_api/app/swagger/decision_reviews/v2/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, RSpec/RepeatedExample, Layout/LineLength
describe 'Supplemental Claims', openapi_spec:, type: :request do
  include DocHelpers
  include FixtureHelpers
  let(:apikey) { 'apikey' }

  path '/supplemental_claims' do
    post 'Creates a new Supplemental Claim' do
      tags 'Supplemental Claims'
      operationId 'createSc'
      description = <<~DESC
        Submits an appeal of type Supplemental Claim. This endpoint is the same as submitting [VA form 200995](https://www.vba.va.gov/pubs/forms/VBA-20-0995-ARE.pdf) via mail or fax directly to the Board of Veterans’ Appeals.
        <br /><br />
        <b>Note about the 5103 Notice of Acknowledgement</b>
        <br /><br />
        The 5103 Notice regarding new & relevant evidence must be acknowledged when the issue(s) being contested is a Disability Compensation issue. The notice can be found here: [http://www.va.gov/disability/how-to-file-claim/evidence-needed](http://www.va.gov/disability/how-to-file-claim/evidence-needed). If the issue(s) being submitted are Disability Compensation and 'No' is selected, the API will return an error.  Please ensure the Veteran reviews the content about the 5103 Notice at the link above.
        <br /><br />
        Supplemental Claims submitted via other avenues that do NOT select 'Yes' for the 5103 Notice are subject to a 30 day suspense so the 5103 Notice can be mailed to the Veteran.
      DESC
      description description

      security DocHelpers.decision_reviews_security_config

      consumes 'application/json'
      produces 'application/json'

      parameter name: :sc_body, in: :body, schema: { '$ref' => '#/components/schemas/scCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200995.json')
        },
        'all fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200995_extra.json').tap do |data|
            data.dig('data', 'attributes')&.delete('potentialPactAct') unless DocHelpers.wip_doc_enabled?(:sc_v2_potential_pact_act)
          end
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'first' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_middle_initial_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'last' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1900-01-01' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_first_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_middle_initial_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_last_name_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:alternate_signer_first_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:alternate_signer_middle_initial_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:alternate_signer_last_name_header]

      response '200', 'Info about a single Supplemental Claim' do
        let(:sc_body) { fixture_as_json('decision_reviews/v2/valid_200995.json') }

        schema '$ref' => '#/components/schemas/scCreateResponse'

        it_behaves_like 'rswag example', desc: 'minimum fields used',
                                         response_wrapper: :normalize_appeal_response,
                                         extract_desc: true
      end

      response '200', 'Info about a single Supplemental Claim' do
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Middle-Initial') { 'm' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }

        let(:sc_body) do
          fixture_as_json('decision_reviews/v2/valid_200995_extra.json').tap do |data|
            data.dig('data', 'attributes')&.delete('potentialPactAct') unless DocHelpers.wip_doc_enabled?(:sc_v2_potential_pact_act)
          end
        end

        schema '$ref' => '#/components/schemas/scCreateResponse'

        it_behaves_like 'rswag example', desc: 'all fields used',
                                         response_wrapper: :normalize_appeal_response,
                                         extract_desc: true
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) do
          fixture_as_json('decision_reviews/v2/valid_200995_extra.json').tap do |data|
            data.dig('data', 'attributes')&.delete('form5103Acknowledged')
            data.dig('data', 'attributes')&.delete('potentialPactAct') unless DocHelpers.wip_doc_enabled?(:sc_v2_potential_pact_act)
          end
        end

        it_behaves_like 'rswag example', desc: 'returns a 422 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/supplemental_claims/{uuid}' do
    get 'Shows a specific Supplemental Claim. (a.k.a. the Show endpoint)' do
      tags 'Supplemental Claims'
      operationId 'showSc'
      description 'Returns all of the data associated with a specific Supplemental Claim.'

      security DocHelpers.decision_reviews_security_config
      produces 'application/json'

      parameter name: :uuid,
                in: :path,
                type: :string,
                description: 'Supplemental Claim UUID',
                example: '7efd87fc-fac1-4851-a4dd-b9aa2533f57f'

      response '200', 'Info about a single Supplemental Claim' do
        schema '$ref' => '#/components/schemas/scCreateResponse'

        let(:uuid) { FactoryBot.create(:supplemental_claim).id }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_appeal_response
      end

      response '404', 'Supplemental Claim not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:uuid) { 'invalid' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  # path '/supplemental_claims/{uuid}/download' do
  # get 'Download a watermarked copy of a submitted Supplemental Claim' do
  # tags 'Supplemental Claims'
  # operationId 'downloadSc'
  # security DocHelpers.decision_reviews_security_config

  # include_examples 'decision reviews PDF download docs', {
  # factory: :extra_supplemental_claim,
  # appeal_type_display_name: 'Supplemental Claim'
  # }
  # end
  # end

  path '/supplemental_claims/schema' do
    get 'Gets the Supplemental Claims JSON Schema.' do
      tags 'Supplemental Claims'
      operationId 'scSchema'
      description 'Returns the [JSON Schema](https://json-schema.org/) for the `POST /supplemental_claims` endpoint.'
      security DocHelpers.decision_reviews_security_config
      produces 'application/json'

      response '200', 'the JSON Schema for POST /supplemental_claims' do
        it_behaves_like 'rswag example', desc: 'returns a 200 response', response_wrapper: :raw_body
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/supplemental_claims/validate' do
    post 'Validates a POST request body against the JSON schema.' do
      tags 'Supplemental Claims'
      operationId 'scValidate'
      description 'Like the POST /supplemental_claims, but only does the validations <b>—does not submit anything.</b>'
      security DocHelpers.decision_reviews_security_config
      consumes 'application/json'
      produces 'application/json'

      parameter name: :sc_body, in: :body, schema: { '$ref' => '#/components/schemas/scCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200995.json')
        },
        'all fields used' => {
          value: FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200995_extra.json').tap do |data|
            data.dig('data', 'attributes')&.delete('potentialPactAct') unless DocHelpers.wip_doc_enabled?(:sc_v2_potential_pact_act)
          end
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header]

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
      parameter AppealsApi::SwaggerSharedComponents.header_params[:claimant_last_name_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:alternate_signer_first_name_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:alternate_signer_middle_initial_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:alternate_signer_last_name_header]

      response '200', 'Valid Minimum' do
        let(:sc_body) { fixture_as_json('decision_reviews/v2/valid_200995.json') }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'sc_validate.json')))

        it_behaves_like 'rswag example', desc: 'returns a 200 response'
      end

      response '200', 'Valid maximum' do
        let(:sc_body) do
          fixture_as_json('decision_reviews/v2/valid_200995_extra.json').tap do |data|
            data.dig('data', 'attributes')&.delete('potentialPactAct') unless DocHelpers.wip_doc_enabled?(:sc_v2_potential_pact_act)
          end
        end

        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'sc_validate.json')))

        it_behaves_like 'rswag example', desc: 'returns a 200 response'
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) do
          request_body = fixture_as_json('decision_reviews/v2/valid_200995.json')
          request_body['data']['attributes'].delete('veteran')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'returns a 422 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/supplemental_claims/evidence_submissions' do
    post 'Get a location for subsequent evidence submission document upload PUT request' do
      tags 'Supplemental Claims'
      operationId 'postSupplementalClaimEvidenceSubmission'
      description <<~DESC
        This is the first step to submitting supporting evidence for a Supplemental Claim.  (See the Evidence Uploads section above for additional information.)
        The Supplemental Claim GUID that is returned when the SC is submitted, is supplied to this endpoint to ensure the SC is in a valid state for sending supporting evidence documents.

        Evidence may be uploaded up to 7 days from the 'created_at' date of the associated Supplemental Claim via 'supplemental_claims/evidence_submissions'.
      DESC

      parameter name: :sc_uuid,
                in: :query,
                type: :string,
                required: true,
                description: 'Associated Supplemental Claim UUID',
                example: '7efd87fc-fac1-4851-a4dd-b9aa2533f57f'

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '123456789' }

      security DocHelpers.decision_reviews_security_config
      produces 'application/json'

      response '202', 'Accepted. Location generated' do
        let(:sc_uuid) { FactoryBot.create(:supplemental_claim).id }

        schema '$ref' => '#/components/schemas/scEvidenceSubmissionResponse'

        before do
          allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(+'http://some.fakesite.com/path/uuid')
        end

        it_behaves_like 'rswag example', desc: 'returns a 202 response',
                                         response_wrapper: :normalize_evidence_submission_response
      end

      response '400', 'Bad Request' do
        let(:sc_uuid) { nil }

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     properties: {
                       title: {
                         type: 'string',
                         example: 'Bad request'
                       },
                       detail: {
                         type: 'string',
                         example: 'Must supply a corresponding SC id in order to submit evidence'
                       },
                       code: {
                         type: 'string',
                         example: '400'
                       },
                       status: {
                         type: 'string',
                         example: '400'
                       }
                     }
                   }
                 }
               }

        it_behaves_like 'rswag example', desc: 'returns a 400 response', skip_match: true
      end

      response '404', 'Associated Supplemental Claim not found' do
        let(:sc_uuid) { nil }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 404 response'
      end

      response '422', 'Validation errors' do
        let(:sc_uuid) { FactoryBot.create(:supplemental_claim).id }
        let(:'X-VA-SSN') { '000000000' }

        schema '$ref' => '#/components/schemas/errorModel'

        it_behaves_like 'rswag example', desc: 'returns a 422 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/sc_upload_path' do
    put 'Accepts Supplemental Claim Evidence Submission document upload.' do
      tags 'Supplemental Claims'
      operationId 'putSupplementalClaimEvidenceSubmission'

      description File.read(AppealsApi::Engine.root.join('app', 'swagger', 'decision_reviews', 'v2', 'put_description.md'))
      security DocHelpers.decision_reviews_security_config

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

  path '/supplemental_claims/evidence_submissions/{uuid}' do
    get 'Returns all of the data associated with a specific Supplemental Claim Evidence Submission.' do
      tags 'Supplemental Claims'
      operationId 'getSupplementalClaimEvidenceSubmission'
      description 'Returns all of the data associated with a specific Supplemental Claim Evidence Submission.'

      security DocHelpers.decision_reviews_security_config
      produces 'application/json'

      parameter name: :uuid, in: :path, type: :string, description: 'Supplemental Claim UUID Evidence Submission'

      response '200', 'Info about a single Supplemental Claim Evidence Submission.' do
        schema '$ref' => '#/components/schemas/scEvidenceSubmissionResponse'

        let(:uuid) { FactoryBot.create(:sc_evidence_submission).guid }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_evidence_submission_response
      end

      response '404', 'Supplemental Claim Evidence Submission not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:uuid) { 'invalid' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response'
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/RepeatedExample, Layout/LineLength
