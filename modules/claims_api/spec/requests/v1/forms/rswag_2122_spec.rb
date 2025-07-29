# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v1'
require 'bgs/power_of_attorney_verifier'
require 'bgs_service/person_web_service'

Rspec.describe 'Power of Attorney', openapi_spec: 'modules/claims_api/app/swagger/claims_api/v1/swagger.json' do
  let(:pws) { ClaimsApi::PersonWebService }

  path '/forms/2122' do
    get 'Gets schema for POA form.' do
      deprecated true
      tags 'Power of Attorney'
      operationId 'get2122JsonSchema'
      produces 'application/json'
      description 'Returns schema to automatically generate a POA form.'
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
    post 'Submit a POA form.' do
      tags 'Power of Attorney'
      operationId 'post2122'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      post_description = <<~VERBIAGE
        Signature images\n\n

        If the request includes signature images for both the Veteran and the representative, the API will:\n
           - Generate VA Form 21-22 PDF for organizations or VA Form 21-22a PDF for individual representatives.\n
           - Automatically establish POA for the representative.\n\n

        The signature can be provided in either of these formats:\n
           - Base64-encoded image or signature block. This allows the API to auto-populate and attach the VA Form
           21-22 without requiring a manual PDF upload.\n
           - PDF of VA Form 21-22 with an ink signature. This should be attached using the PUT /forms/2122/{id}
           endpoint.\n\n

           If signature images are not included in the initial request, the response will return an id which must be
           used to submit the signed PDF via the PUT /forms/2122/{id} endpoint.\n\n

        Dependent claimant information:\n
           - If dependent claimant information is included in the request, the dependentʼs relationship to the Veteran
           will be validated.\n
           - In this case, the representative will be appointed to the dependent claimant, not the Veteran.\n\n

        Response information:\n
           - A successful submission returns a 200 response, indicating that the request was successfully processed.\n
           - A 200 response does not confirm that the POA has been appointed.\n
           - To check the status of a POA submission, use the GET /forms/2122/{id} endpoint.\n
      VERBIAGE
      description post_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      claimant_data = {
        'firstName' => 'Mary',
        'lastName' => 'Lincoln',
        'address' => {
          'numberAndStreet' => '123 anystreet',
          'city' => 'anytown',
          'state' => 'OR',
          'country' => 'USA',
          'zipFirstFive' => '12345'
        },
        'relationship' => 'Spouse'
      }

      request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                                                    'form_2122_json_api.json').read)

      request_template_with_dependent = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                                                                   'form_2122_json_api.json').read)
      request_template_with_dependent['data']['attributes']['claimant'] = claimant_data

      parameter name: :power_of_attorney_request, in: :body,
                schema: SwaggerSharedComponents::V1.body_examples[:power_of_attorney][:schema]

      parameter in: :body, examples: {
        'POA for Veteran' => {
          value: request_template
        },
        'POA for Dependent Claimant' => {
          value: request_template_with_dependent
        }
      }

      describe 'Getting a successful response' do
        response '200', '2122 Response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'power_of_attorney', 'submission.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:power_of_attorney_request) do
            data
          end

          let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code!).and_return(true)
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code_for_current_user!).and_return(true)
            stub_poa_verification
            allow_any_instance_of(pws)
              .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
            allow(bgs_poa_verifier).to receive(:current_poa_code).and_return(nil)

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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end
          let(:Authorization) { nil }

          let(:power_of_attorney_request) do
            data
          end

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
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
                                            'default_with_source.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json').read
            temp = JSON.parse(temp)
            temp['data']['attributes']['serviceOrganization']['poaCode'] = nil

            temp
          end

          let(:power_of_attorney_request) do
            data
          end

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/2122/{id}' do
    put 'Upload a signed 21-22 document.' do
      tags 'Power of Attorney'
      operationId 'upload2122Attachment'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'multipart/form-data'
      produces 'application/json'
      put_description = <<~VERBIAGE
        Accepts a document binary as part of a multipart payload.
        Use this PUT endpoint after the POST endpoint for uploading the signed 21-22 PDF form.\n
      VERBIAGE
      description put_description

      parameter name: :id, in: :path, type: :string, description: 'UUID given when Power of Attorney was submitted'

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
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
        response '200', '2122 Response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'power_of_attorney', 'upload.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)
              allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }
          let(:Authorization) { nil }

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { 999_999_999 }

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
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

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_return(nil)
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

          it 'returns a valid 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 424 response' do
        response '424', 'Failed Dependency' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_raise(BGS::ShareError.new('HelloWorld'))
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

          it 'returns a valid 424 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 400 response' do
        response '400', 'Bad Request' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)
          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney) }
          let(:attachment) { nil }
          let(:id) { power_of_attorney.id }

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            stub_poa_verification

            mock_acg(scopes) do
              allow_any_instance_of(BGS::PersonWebService)
                .to receive(:find_by_ssn).and_raise(BGS::ShareError.new('HelloWorld'))
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
    end
  end

  path '/forms/2122/{id}' do
    get 'Check POA status by ID.' do
      tags 'Power of Attorney'
      operationId 'get2122poa'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Based on ID, returns a 21-22 submission and current status.'

      parameter name: :id, in: :path, type: :string, description: 'The ID of the 21-22 submission'

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }

      let(:Authorization) { 'Bearer token' }

      describe 'Getting a 200 response' do
        response '200', '2122 response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'power_of_attorney', 'get.json').read)

          let(:headers) do
            { 'X-VA-SSN': '796-04-3735',
              'X-VA-First-Name': 'WESLEY',
              'X-VA-Last-Name': 'FORD',
              'X-Consumer-Username': 'TestConsumer',
              'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
              'X-VA-Gender': 'M' }
          end
          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney, auth_headers: headers) }
          let(:id) { power_of_attorney.id }

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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:headers) do
            { 'X-VA-SSN': '796-04-3735',
              'X-VA-First-Name': 'WESLEY',
              'X-VA-Last-Name': 'FORD',
              'X-Consumer-Username': 'TestConsumer',
              'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
              'X-VA-Gender': 'M' }
          end
          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney, auth_headers: headers) }
          let(:id) { power_of_attorney.id }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
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

          let(:headers) do
            { 'X-VA-SSN': '796-04-3735',
              'X-VA-First-Name': 'WESLEY',
              'X-VA-Last-Name': 'FORD',
              'X-Consumer-Username': 'TestConsumer',
              'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
              'X-VA-Gender': 'M' }
          end
          let(:scopes) { %w[claim.read claim.write] }
          let(:id) { 999_999_999 }

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

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/2122/active' do
    get 'Check active POA status.' do
      tags 'Power of Attorney'
      operationId 'getActive2122Poa'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      active_description = <<~VERBIAGE
        Returns the last active POA for a claimant.
        To check the status of new POA submissions, use the GET /forms/2122/{id} endpoint.\n
      VERBIAGE
      description active_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }

      let(:Authorization) { 'Bearer token' }

      describe 'Getting a 200 response' do
        response '200', '2122 response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'power_of_attorney', 'active.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }
          let(:representative_info) do
            {
              first_name: 'Jane',
              last_name: 'Doe',
              organization_name: nil,
              phone_number: '555-555-5555'
            }
          end

          before do |example|
            stub_poa_verification
            create(:representative, first_name: 'Abraham', last_name: 'Lincoln', poa_codes: %w[A01])

            mock_acg(scopes) do
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              expect(bgs_poa_verifier).to receive(:current_poa_code).and_return('A01').exactly(3).times
              expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
              expect_any_instance_of(
                ClaimsApi::V1::Forms::PowerOfAttorneyController
              ).to receive(:build_representative_info).and_return(representative_info)
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              allow(Veteran::Service::Representative).to receive(:for_user).and_return(true)
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

          it 'returns a valid 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/2122/validate' do
    post '21-22 POA form submission test run.' do
      deprecated true
      tags 'Power of Attorney'
      operationId 'validate2122poa'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      validation_description = <<~VERBIAGE
        Test to make sure the form submission works with your parameters.
      VERBIAGE
      description validation_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      parameter SwaggerSharedComponents::V1.body_examples[:power_of_attorney]

      describe 'Getting a successful response' do
        response '200', '2122 Response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'power_of_attorney', 'validate.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code!).and_return(true)
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code_for_current_user!).and_return(true)
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
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
                                            'default_with_source.json').read)

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) { { data: { attributes: nil } } }

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end
