# frozen_string_literal: true

require 'swagger_helper'
require 'rails_helper'
require_relative '../../support/swagger_shared_components'

describe 'Disability Claims' do # rubocop:disable RSpec/DescribeClass
  path '/forms/526' do
    get 'Get a 526 schema for a claim.' do
      deprecated true
      tags 'Disability'
      operationId 'get526JsonSchema'
      security [bearer_token: []]
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
      security [bearer_token: []]
      consumes 'application/json'
      produces 'application/json'
      post_description = <<~VERBIAGE
        Establishes a [Disability Compensation Claim](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf) in VBMS. Submits any PDF attachments as a multi-part payload and returns an ID. For claims that are not original claims, this endpoint generates a filled 526 PDF along with the submission.\n<br/><br/>\nA 200 response indicates the submission was successful, but the claim has not reached VBMS until it has a “claim established” status. Check claim status using the GET /claims/{id} endpoint.\n<br/><br/>\n**Original claims**<br/>\nAn original claim is the Veteran’s first claim filed with VA, regardless of the claim type or status. The original claim must have either the Veteran’s wet signature or e-signature. Once there is an original claim on file, future claims may be submitted by a representative without the Veteran’s signature. Uploading a PDF for subsequent claims is not required or recommended.\n<br/><br/>\nPOST the original claim with the autoCestPDFGenerationDisabled boolean as true. After a 200 response, use the PUT /forms/526/{id} endpoint to upload a scanned PDF of your form, signed in ink or e-signature, by the Veteran.\n<br/><br/>\nThe claim data submitted through the POST endpoint must match the signed PDF uploaded through the PUT endpoint. If it does not, VA will manually update the data to match the PDF, and your claim may not process correctly.\n<br/><br/>\n**Standard and fully developed claims (FDCs)**<br/>\n[Fully developed claims (FDCs)](https://www.va.gov/disability/how-to-file-claim/evidence-needed/fully-developed-claims/) are claims certified by the submitter to include all information needed for processing. These claims process faster than claims submitted through the standard claim process. If a claim is certified for the FDC, but is missing needed information, it will route through the standard claim process.\n<br/><br/>\nTo certify a claim for the FDC process, set the standardClaim indicator to false.\n<br/><br/>\n**Flashes and special issues**<br/>\nIncluding flashes and special issues in your 526 claim submission helps VA properly route and prioritize current and future claims for the Veteran and reduces claims processing time.\n\n - Flashes are attributes that describe special circumstances which apply to a Veteran, such as homelessness or terminal illness. See a full list of [supported flashes](https://github.com/department-of-veterans-affairs/vets-api/blob/30659c8e5b2dd254d3e6b5d18849ff0d5f2e2356/modules/claims_api/config/schemas/526.json#L35).\n - Special Issues are attributes that describe special circumstances which apply to a particular claim, such as PTSD. See a full list of [supported special Issues](https://github.com/department-of-veterans-affairs/vets-api/blob/30659c8e5b2dd254d3e6b5d18849ff0d5f2e2356/modules/claims_api/config/schemas/526.json#L28).\n
      VERBIAGE
      description post_description

      parameter SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      parameter SwaggerSharedComponents.body_examples[:disability_compensation]

      describe 'Getting a successful response' do
        response '200', '526 Response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'disability', 'submission.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled

            temp
          end

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
              VCR.use_cassette('evss/claims/claims') do
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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
              VCR.use_cassette('evss/claims/claims') do
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default_with_source.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }

          def make_stubbed_request(example)
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
              VCR.use_cassette('evss/claims/claims') do
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
              temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
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
      security [bearer_token: []]
      consumes 'multipart/form-data'
      produces 'application/json'
      put_description = <<~VERBIAGE
        Used to upload a completed, signed 526 PDF to establish an original claim. Use this endpoint only after following the instructions in the POST /forms/526 endpoint to begin the claim submission.\n<br/><br/>\nThis endpoint works by accepting a document binary PDF as part of a multi-part payload (for example, attachment1, attachment2, attachment3). Each attachment should be encoded separately rather than encoding the whole payload together as with the Benefits Intake API.\n<br/><br/>\nFor other attachments, such as medical records, use the /forms/526/{id}/attachments endpoint.\n
      VERBIAGE
      description put_description

      parameter name: :id, in: :path, type: :string, description: 'UUID given when Disability Claim was submitted'

      parameter SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'disability', 'upload.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:attachment) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { 999_999_999 }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { auto_claim.id }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim, :autoCestPDFGeneration_disabled) }
          let(:attachment) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
      security [bearer_token: []]
      consumes 'application/json'
      produces 'application/json'
      validate_description = <<~VERBIAGE
        Test to make sure the form submission works with your parameters.
        Submission validates against the schema returned by the GET /forms/526 endpoint.
      VERBIAGE
      description validate_description

      parameter SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      parameter SwaggerSharedComponents.body_examples[:disability_compensation]

      describe 'Getting a successful response' do
        response '200', '526 Response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'disability', 'validate.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled

            temp
          end

          before do |example|
            stub_poa_verification
            stub_mpi

            VCR.use_cassette('evss/disability_compensation_form/form_526_valid_validation') do
              with_okta_user(scopes) do
                VCR.use_cassette('evss/claims/claims') do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
            temp = JSON.parse(temp)
            temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            VCR.use_cassette('evss/disability_compensation_form/form_526_valid_validation') do
              with_okta_user(scopes) do
                VCR.use_cassette('evss/claims/claims') do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default_with_source.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_cest_pdf_generation_disabled) { false }
          let(:data) { { data: { attributes: nil } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
              VCR.use_cassette('evss/disability_compensation_form/form_526_invalid_validation') do
                VCR.use_cassette('evss/claims/claims') do
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
      security [bearer_token: []]
      consumes 'multipart/form-data'
      produces 'application/json'
      put_description = <<~VERBIAGE
        Used to attach supporting documents for a 526 claim. For wet-signature PDFs, use the PUT /forms/526/{id} endpoint.\n
        <br/><br/>\nThis endpoint accepts a document binary PDF as part of a multi-part payload (for example, attachment1, attachment2, attachment3).\n
      VERBIAGE
      description put_description

      parameter name: :id, in: :path, type: :string, description: 'UUID given when Disability Claim was submitted'

      parameter SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'disability', 'attachments.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment1) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { auto_claim.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment1) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { auto_claim.id }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:attachment1) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf")
          end
          let(:id) { 999_999_999 }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
