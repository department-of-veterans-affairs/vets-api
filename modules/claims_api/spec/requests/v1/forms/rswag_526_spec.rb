# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v1'

Rspec.describe 'Disability Claims', openapi_spec: 'modules/claims_api/app/swagger/claims_api/v1/swagger.json' do
  path '/forms/526' do
    get 'Get a 526 schema for a claim.' do
      deprecated true
      tags 'Disability'
      operationId 'get526JsonSchema'
      produces 'application/json'
      get_schema_description = <<~VERBIAGE
        Returns a single 526 schema to automatically generate a form. Using this GET endpoint allows users to download our current validations.
      VERBIAGE
      description get_schema_description

      let(:Authorization) { 'Bearer token' }

      describe 'Getting a successful response' do
        response '200', 'schema response' do
          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end

    post 'Submits form 526' do
      tags 'Disability'
      operationId 'post526Claim'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      post_description = <<~VERBIAGE
        Establishes a [Disability Compensation Claim](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf) in VBMS. Submits any PDF attachments as a multi-part payload and returns an ID. For claims that are not original claims, this endpoint generates a filled 526 PDF along with the submission.\n<br/><br/>\nA 200 response indicates the submission was successful, but the claim has not reached VBMS until it has a “claim established” status. Check claim status using the GET /claims/{id} endpoint.\n<br/><br/>\n**Original claims**<br/>\nAn original claim is the Veteran’s first claim filed with VA, regardless of the claim type or status. The original claim must have either the Veteran’s wet signature or e-signature. Once there is an original claim on file, future claims may be submitted by a representative without the Veteran’s signature. Uploading a PDF for subsequent claims is not required or recommended.\n<br/><br/>\nPOST the original claim with the autoCestPDFGenerationDisabled boolean as true. After a 200 response, use the PUT /forms/526/{id} endpoint to upload a scanned PDF of your form, signed in ink or e-signature, by the Veteran.\n<br/><br/>\nThe claim data submitted through the POST endpoint must match the signed PDF uploaded through the PUT endpoint. If it does not, VA will manually update the data to match the PDF, and your claim may not process correctly.\n<br/><br/>\n**Standard and fully developed claims (FDCs)**<br/>\n[Fully developed claims (FDCs)](https://www.va.gov/disability/how-to-file-claim/evidence-needed/fully-developed-claims/) are claims certified by the submitter to include all information needed for processing. These claims process faster than claims submitted through the standard claim process. If a claim is certified for the FDC, but is missing needed information, it will route through the standard claim process.\n<br/><br/>\nTo certify a claim for the FDC process, set the standardClaim indicator to false.\n<br/><br/>\n**Flashes and special issues**<br/>\nIncluding flashes and special issues in your 526 claim submission helps VA properly route and prioritize current and future claims for the Veteran and reduces claims processing time.\n\n - Flashes are attributes that describe special circumstances which apply to a Veteran, such as homelessness or terminal illness.\n - Special Issues are attributes that describe special circumstances which apply to a particular claim, such as PTSD.
        \n\n<br/>\n**Notes On 'disabilityActionType' and 'secondaryDisabilities'**<br/>
        \n- We now recommend using the value **NEW** instead of **INCREASE** for **disabilityActionType** in the Benefits Claims API. For context:
        \n  - When requesting a disability **INCREASE**, the **ratedDisabiltiyId** and **diagnosticCode** are also required. The Benefits Claims API doesn't have access to specific values that are required for these fields. By submitting **NEW** for **disabilityActionType**, these values are not required.
        \n  - Using **NEW** instead of **INCREASE** will not significantly impact how the claim is processed by VA.
        \n- We don’t support the **disabilityActionType** of **REOPEN**. It didn't provide value in claim processing because its functionality wasn’t supported.
        \n- We now recommend using the **disabilities** attribute with a **disabilityActionType** value of **NEW**, instead of sending disabilities as nested values with the **secondaryDisabilities** attribute.
        \n  - This approach will not significantly impact how the claim is processed by VA and is better aligned with the 526 form.
        \n  - **secondaryDisabilties** is required if the primary disability has a **disabilityActionType** equal to **NONE**.
        \n- If you are required to use **secondaryDisabilities**, there are additional validations that apply:
        \n  - **disabilityActionType** of the secondary disability must equal **SECONDARY**.
        \n  - **classificationCode** in the secondary disability is optional. If provided, its value must match the value of the **name** attribute.
        \n  - If **classificationCode** isn’t provided, then the **name** attribute must not contain any special characters and must not exceed 255 characters.
        \n  - **specialIssues** must be nil.
        \n  - **approximateBeginDate** was added, but it’s optional. If provided, it must be a valid date.
      VERBIAGE
      description post_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1965-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      parameter SwaggerSharedComponents::V1.body_examples[:disability_compensation]

      describe 'Getting a successful response' do
        response '200', '526 Response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'disability', 'submission.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
            temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

            temp
          end

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  submit_request(example.metadata)
                end
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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
                  submit_request(example.metadata)
                end
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default_with_source.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }

          def make_stubbed_request(example)
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                submit_request(example.metadata)
              end
            end
          end

          def append_example_metadata(example, response)
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

          context 'Violates JSON Schema' do
            let(:data) do
              temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
              temp = JSON.parse(temp)
              temp['data']['attributes']['someBadKey'] = 'someValue'

              temp
            end

            before do |example|
              make_stubbed_request(example)
            end

            after do |example|
              append_example_metadata(example, response)
            end

            it 'returns a 422 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end

          context 'Not a JSON Object' do
            let(:data) do
              'This is not valid JSON'
            end

            before do |example|
              make_stubbed_request(example)
            end

            after do |example|
              append_example_metadata(example, response)
            end

            it 'returns a 422 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end
      end
    end
  end

  path '/forms/526/{id}' do
    put 'Upload a 526 document' do
      tags 'Disability'
      operationId 'upload526Attachment'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'multipart/form-data'
      produces 'application/json'
      put_description = <<~VERBIAGE
        Used to upload a completed, signed 526 PDF to establish an original claim. Use this endpoint only after following the instructions in the POST /forms/526 endpoint to begin the claim submission.\n<br/><br/>\nThis endpoint works by accepting a document binary PDF as part of a multi-part payload (for example, attachment1, attachment2, attachment3). Each attachment should be encoded separately rather than encoding the whole payload together as with the Benefits Intake API.\n<br/><br/>\nFor other attachments, such as medical records, use the /forms/526/{id}/attachments endpoint.\n
      VERBIAGE
      description put_description

      parameter name: :id, in: :path, type: :string, description: 'UUID given when Disability Claim was submitted'

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1965-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      attachment_description = <<~VERBIAGE
        Attachment contents. Must be provided in binary PDF or [base64 string](https://raw.githubusercontent.com/department-of-veterans-affairs/vets-api/master/modules/claims_api/spec/fixtures/base64pdf) format and less than 11 in x 11 in.
      VERBIAGE
      parameter name: :attachment,
                in: :formData,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    attachment: {
                      type: :file,
                      description: attachment_description
                    }
                  }
                }

      describe 'Getting a successful response' do
        response '200', '526 Response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'disability', 'upload.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim, status: ClaimsApi::AutoEstablishedClaim::PENDING) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 400 response' do
        response '400', 'Bad Request' do
          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim, :errored) }
          let(:attachment) { nil }
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification
            mock_acg(scopes) do
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

          it 'returns a 400 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { 999_999_999 }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
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
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { auto_claim.id }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
              allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim, :autoCestPDFGeneration_disabled) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/526/validate' do
    post 'Validates a 526 claim form submission.' do
      deprecated true
      tags 'Disability'
      operationId 'post526ClaimValidate'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      validate_description = <<~VERBIAGE
        Test to make sure the form submission works with your parameters.
        Submission validates against the schema returned by the GET /forms/526 endpoint.
      VERBIAGE
      description validate_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1965-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      parameter SwaggerSharedComponents::V1.body_examples[:disability_compensation]

      describe 'Getting a successful response' do
        response '200', '526 Response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'disability', 'validate.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
            temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

            temp
          end

          before do |example|
            stub_poa_verification
            stub_claims_api_auth_token

            VCR.use_cassette('claims_api/evss/disability_compensation_form/form_526_valid_validation') do
              mock_acg(scopes) do
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    VCR.use_cassette('claims_api/v1/disability_comp/bd_token') do
                      VCR.use_cassette('claims_api/v1/disability_comp/validate') do
                        submit_request(example.metadata)
                      end
                    end
                  end
                end
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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            VCR.use_cassette('claims_api/evss/disability_compensation_form/form_526_valid_validation') do
              mock_acg(scopes) do
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
                  submit_request(example.metadata)
                end
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default_with_source.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) { { data: { attributes: nil } } }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/evss/disability_compensation_form/form_526_invalid_validation') do
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  submit_request(example.metadata)
                end
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/526/{id}/attachments' do
    post 'Upload documents supporting a 526 claim' do
      tags 'Disability'
      operationId 'upload526Attachments'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'multipart/form-data'
      produces 'application/json'
      put_description = <<~VERBIAGE
        Used to attach supporting documents for a 526 claim. For wet-signature PDFs, use the PUT /forms/526/{id} endpoint.\n
        <br/><br/>\nThis endpoint accepts a document binary PDF as part of a multi-part payload (for example, attachment1, attachment2, attachment3).\n
      VERBIAGE
      description put_description

      parameter name: :id, in: :path, type: :string, description: 'UUID given when Disability Claim was submitted'

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1965-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      attachment_description = <<~VERBIAGE
        Attachment contents. Must be provided in binary PDF or [base64 string](https://raw.githubusercontent.com/department-of-veterans-affairs/vets-api/master/modules/claims_api/spec/fixtures/base64pdf) format and less than 11 in x 11 in.
      VERBIAGE
      parameter name: :attachment1,
                in: :formData,
                schema: {
                  type: :object,
                  properties: {
                    attachment1: {
                      type: :file,
                      description: attachment_description
                    },
                    attachment2: {
                      type: :file,
                      description: attachment_description
                    }
                  }
                }

      describe 'Getting a successful response' do
        response '200', 'upload response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'disability', 'attachments.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim, :pending) }
          let(:attachment1) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment1) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { auto_claim.id }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
              allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:attachment1) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { 999_999_999 }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
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
      end
    end
  end
end
