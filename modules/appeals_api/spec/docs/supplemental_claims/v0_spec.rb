# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'doc_helpers.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_pdf_downloads.rb')

def openapi_spec
  "modules/appeals_api/app/swagger/supplemental_claims/v0/swagger#{DocHelpers.doc_suffix}.json"
end

# rubocop:disable RSpec/VariableName, RSpec/RepeatedExample, Layout/LineLength
RSpec.describe 'Supplemental Claims', openapi_spec:, type: :request do
  include DocHelpers
  let(:Authorization) { 'Bearer TEST_TOKEN' }

  path '/forms/200995' do
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

      security DocHelpers.oauth_security_config(AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST])

      consumes 'application/json'
      produces 'application/json'

      parameter name: :sc_body,
                in: :body,
                schema: { '$ref' => '#/components/schemas/scCreate' },
                examples: {
                  'minimum fields used' => { value: FixtureHelpers.fixture_as_json('supplemental_claims/v0/valid_200995.json') },
                  'all fields used' => { value: FixtureHelpers.fixture_as_json('supplemental_claims/v0/valid_200995_extra.json') }
                }

      scopes = %w[system/SupplementalClaims.write]

      response '201', 'Supplemental Claim created' do
        let(:sc_body) { fixture_as_json('supplemental_claims/v0/valid_200995.json') }

        schema '$ref' => '#/components/schemas/scCreateResponse'

        it_behaves_like 'rswag example', desc: 'minimum fields used',
                                         response_wrapper: :normalize_appeal_response,
                                         extract_desc: true,
                                         scopes:
      end

      response '201', 'Supplemental Claim created' do
        let(:sc_body) do
          fixture_as_json('supplemental_claims/v0/valid_200995_extra.json').tap do |data|
            data['data']['attributes']['claimant'].merge!({ firstName: 'first', middleInitial: 'm', lastName: 'last' })
          end
        end

        schema '$ref' => '#/components/schemas/scCreateResponse'

        it_behaves_like 'rswag example', desc: 'all fields used',
                                         response_wrapper: :normalize_appeal_response,
                                         extract_desc: true,
                                         scopes:
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) { nil }

        it_behaves_like 'rswag example',
                        desc: 'Body is not a JSON object',
                        extract_desc: true,
                        scopes:
      end

      response '403', 'Forbidden attempt using a veteran-scoped OAuth token to create a Supplemental Claim for another veteran' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) do
          fixture_as_json('supplemental_claims/v0/valid_200995.json').tap do |data|
            data['data']['attributes']['veteran']['icn'] = '1234567890V987654'
          end
        end

        it_behaves_like 'rswag example', scopes: %w[veteran/SupplementalClaims.write]
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) do
          fixture_as_json('supplemental_claims/v0/valid_200995_extra.json').tap do |data|
            data.dig('data', 'attributes')&.delete('form5103Acknowledged')
          end
        end

        it_behaves_like 'rswag example', desc: 'returns a 422 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/forms/200995/{id}' do
    get 'Show a specific Supplemental Claim' do
      tags 'Supplemental Claims'
      operationId 'showSc'
      description 'Returns basic data associated with a specific Supplemental Claim.'
      security DocHelpers.oauth_security_config(AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET])
      produces 'application/json'

      parameter name: :id,
                in: :path,
                description: 'Supplemental Claim UUID',
                example: '7efd87fc-fac1-4851-a4dd-b9aa2533f57f',
                schema: { type: :string, format: :uuid }

      veteran_scopes = %w[veteran/SupplementalClaims.read]

      response '200', 'Success' do
        schema '$ref' => '#/components/schemas/scCreateResponse'

        let(:id) { create(:supplemental_claim_v0).id }

        it_behaves_like 'rswag example', desc: 'returns a 200 response',
                                         response_wrapper: :normalize_appeal_response,
                                         scopes: veteran_scopes
      end

      response '403', 'Forbidden access with a veteran-scoped OAuth token to an unowned Supplemental Claim' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:id) { create(:supplemental_claim_v0, veteran_icn: '1234567890V123456').id }

        it_behaves_like 'rswag example',
                        desc: 'with a veteran-scoped OAuth token for a Veteran who does not own the Supplemental Claim',
                        scopes: veteran_scopes
      end

      response '404', 'Supplemental Claim not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:id) { '00000000-0000-0000-0000-000000000000' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes: veteran_scopes
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/forms/200995/{id}/download' do
    get 'Download a watermarked copy of a submitted Supplemental Claim' do
      scopes = AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET]
      tags 'Supplemental Claims'
      operationId 'downloadSc'
      security DocHelpers.oauth_security_config(scopes)

      include_examples 'PDF download docs', {
        factory: :supplemental_claim_v0,
        appeal_type_display_name: 'Supplemental Claim',
        scopes:
      }
    end
  end

  path '/schemas/{schema_type}' do
    get 'Gets the Supplemental Claims JSON Schema.' do
      scopes = AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET]
      tags 'Supplemental Claims'
      operationId 'scSchema'
      description 'Returns the [JSON Schema](https://json-schema.org/) for the `POST /forms/200995` endpoint.'
      security DocHelpers.oauth_security_config(scopes)
      produces 'application/json'

      examples = {
        '200995': { value: '200995' },
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

  path '/forms/200995/validate' do
    post 'Validates a POST request body against the JSON schema.' do
      scopes = AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST]
      tags 'Supplemental Claims'
      operationId 'scValidate'
      description 'Like the POST /supplemental_claims, but only does the validations <b>—does not submit anything.</b>'
      security DocHelpers.oauth_security_config(scopes)
      consumes 'application/json'
      produces 'application/json'

      parameter name: :sc_body,
                in: :body,
                schema: { '$ref' => '#/components/schemas/scCreate' },
                examples: {
                  'minimum fields used' => { value: FixtureHelpers.fixture_as_json('supplemental_claims/v0/valid_200995.json') },
                  'all fields used' => { value: FixtureHelpers.fixture_as_json('supplemental_claims/v0/valid_200995_extra.json') }
                }

      response '200', 'Valid Minimum' do
        let(:sc_body) { fixture_as_json('supplemental_claims/v0/valid_200995.json') }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'sc_validate.json')))

        it_behaves_like 'rswag example', desc: 'returns a 200 response', scopes:
      end

      response '200', 'Valid maximum' do
        let(:sc_body) { fixture_as_json('supplemental_claims/v0/valid_200995_extra.json') }
        let(:'X-VA-NonVeteranClaimant-First-Name') { 'first' }
        let(:'X-VA-NonVeteranClaimant-Last-Name') { 'last' }

        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'sc_validate.json')))

        it_behaves_like 'rswag example', desc: 'returns a 200 response', scopes:
      end

      response '422', 'Violates JSON schema' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:sc_body) do
          request_body = fixture_as_json('supplemental_claims/v0/valid_200995.json')
          request_body['data']['attributes'].delete('veteran')
          request_body
        end

        it_behaves_like 'rswag example', desc: 'returns a 422 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/evidence-submissions' do
    post 'Get a location for subsequent evidence submission document upload PUT request' do
      scopes = AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST]
      tags 'Supplemental Claims'
      operationId 'postSupplementalClaimEvidenceSubmission'
      description <<~DESC
        This is the first step to submitting supporting evidence for a Supplemental Claim.  (See the Evidence Uploads section above for additional information.)
        The Supplemental Claim GUID that is returned when the SC is submitted, is supplied to this endpoint to ensure the SC is in a valid state for sending supporting evidence documents.

        Evidence may be uploaded up to 7 days from the 'created_at' date of the associated Supplemental Claim via 'supplemental_claims/evidence_submissions'.
      DESC

      security DocHelpers.oauth_security_config(scopes)

      consumes 'application/json'
      produces 'application/json'

      parameter name: :sc_es_body, in: :body, schema: { '$ref' => '#/components/schemas/scEvidenceSubmissionCreate' }

      let(:ssn) { '123456789' }
      let(:scId) { create(:supplemental_claim_v0).id }
      let(:sc_es_body) { { ssn:, scId: } }

      response '201', 'Location created' do
        schema '$ref' => '#/components/schemas/scEvidenceSubmissionResponse'

        before do
          allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(+'http://path.to.upload/location/uuid')
        end

        it_behaves_like 'rswag example',
                        desc: 'returns a 201 response',
                        response_wrapper: :normalize_evidence_submission_response,
                        scopes:
      end

      response '400', 'Bad Request' do
        let(:scId) { nil }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 400 response', skip_match: true, scopes:
      end

      response '404', 'Associated Supplemental Claim not found' do
        let(:scId) { '00000000-0000-0000-0000-000000000000' }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      response '422', 'Validation errors' do
        let(:ssn) { '000000000' }
        schema '$ref' => '#/components/schemas/errorModel'
        it_behaves_like 'rswag example', desc: 'returns a 422 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/sc-upload-path' do
    put 'Accepts Supplemental Claim Evidence Submission document upload.' do
      scopes = AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST]
      tags 'Supplemental Claims'
      operationId 'putSupplementalClaimEvidenceSubmission'

      description File.read(AppealsApi::Engine.root.join('app', 'swagger', 'supplemental_claims', 'v0', 'put_description.md'))
      security DocHelpers.oauth_security_config(scopes)

      parameter name: :'Content-MD5', in: :header, type: :string, description: 'Base64-encoded 128-bit MD5 digest of the message. Use for integrity control.'

      let(:'Content-MD5') { nil }

      response '200', 'Document upload staged' do
        # rubocop:disable RSpec/NoExpectationExample
        it 'returns a 200 response' do |example|
          # noop
        end
        # rubocop:enable RSpec/NoExpectationExample
      end

      response '400', 'Document upload failed' do
        produces 'application/xml'

        schema type: :object,
               description: 'Document upload failed',
               xml: { name: 'Error' },
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

        # rubocop:disable RSpec/NoExpectationExample
        it 'returns a 400 response' do |example|
          # noop
        end
        # rubocop:enable RSpec/NoExpectationExample
      end

      it_behaves_like 'rswag 500 response'
    end
  end

  path '/evidence-submissions/{id}' do
    get 'Returns all of the data associated with a specific Supplemental Claim Evidence Submission.' do
      tags 'Supplemental Claims'
      operationId 'getSupplementalClaimEvidenceSubmission'
      description 'Returns all of the data associated with a specific Supplemental Claim Evidence Submission.'

      security DocHelpers.oauth_security_config(
        AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET]
      )

      produces 'application/json'

      parameter name: :id,
                in: :path,
                description: 'Supplemental Claim UUID Evidence Submission',
                schema: {
                  type: :string,
                  format: :uuid
                }

      scopes = %w[system/SupplementalClaims.read]

      response '200', 'Info about a single Supplemental Claim Evidence Submission.' do
        schema '$ref' => '#/components/schemas/scEvidenceSubmissionResponse'

        let(:sc) { create(:supplemental_claim_v0) }
        let(:id) { create(:evidence_submission_v0, supportable: sc).guid }

        it_behaves_like 'rswag example',
                        desc: 'returns a 200 response',
                        response_wrapper: :normalize_evidence_submission_response,
                        scopes:
      end

      response '403', 'Forbidden attempt using a veteran-scoped OAuth token to view an Evidence Submission belonging to another Veteran' do
        schema '$ref' => '#/components/schemas/errorModel'
        let(:sc) { create(:supplemental_claim_v0, veteran_icn: '1111111111V111111') }
        let(:id) { create(:evidence_submission_v0, supportable: sc).guid }

        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes: %w[veteran/SupplementalClaims.read]
      end

      response '404', 'Supplemental Claim Evidence Submission not found' do
        schema '$ref' => '#/components/schemas/errorModel'

        let(:id) { '00000000-0000-0000-0000-000000000000' }

        it_behaves_like 'rswag example', desc: 'returns a 404 response', scopes:
      end

      it_behaves_like 'rswag 500 response'
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/RepeatedExample, Layout/LineLength
