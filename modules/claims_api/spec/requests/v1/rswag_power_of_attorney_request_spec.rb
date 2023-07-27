# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../support/swagger_shared_components/v1'

describe 'Power of Attorney', swagger_doc: 'modules/claims_api/app/swagger/claims_api/v1/swagger.json' do # rubocop:disable RSpec/DescribeClass
  let(:pws) { ClaimsApi::LocalBGS }

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
        The endpoint establishes POA for a representative.
        Once ID.me authorizes the Veteran or VSO via OpenID, this endpoint requests the:
        \n - poaCode\n - Signature, which can be a:
        \n   - Base64-encoded image or signature block, allowing the API to auto-populate
        and attach the VA 21-22 form to the request without requiring a PDF upload, or
        \n   - PDF documentation of VA 21-22 form with an ink signature, attached using the PUT /forms/2122/{id} endpoint
        \n\nA 200 response means the submission was successful, but does not mean the POA is effective.
        Check the status of a POA submission by using the GET /forms/2122/{id} endpoint.\n
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

      parameter SwaggerSharedComponents::V1.body_examples[:power_of_attorney]

      describe 'Getting a successful response' do
        response '200', '2122 Response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'power_of_attorney', 'submission.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json'))
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code!).and_return(true)
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code_for_current_user!).and_return(true)
            stub_poa_verification
            stub_mpi
            allow_any_instance_of(pws)
              .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })

            with_okta_user(scopes) do
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json'))
            temp = JSON.parse(temp)

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
                                                      'default_with_source.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json'))
            temp = JSON.parse(temp)
            temp['data']['attributes']['serviceOrganization']['poaCode'] = nil

            temp
          end

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'power_of_attorney', 'upload.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:attachment) do
            Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { 999_999_999 }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
          let(:attachment) do
            Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                     .to_s)
          end
          let(:id) { power_of_attorney.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))
          let(:scopes) { %w[claim.read claim.write] }
          let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
          let(:attachment) { nil }
          let(:id) { power_of_attorney.id }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'power_of_attorney', 'get.json')))

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
            stub_mpi

            with_okta_user(scopes) do
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
            stub_mpi

            with_okta_user(scopes) do
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
            stub_mpi

            with_okta_user(scopes) do
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
        Returns the last active POA for a Veteran.
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'power_of_attorney', 'active.json')))

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
            stub_mpi

            with_okta_user(scopes) do
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              allow(::Veteran::Service::Representative).to receive(:for_user).and_return(true)
              expect(bgs_poa_verifier).to receive(:current_poa).and_return(Struct.new(:code).new('HelloWorld'))
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              allow(::Veteran::Service::Representative).to receive(:for_user).and_return(true)
              expect(bgs_poa_verifier).to receive(:current_poa).and_return(Struct.new(:code).new(nil))
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'power_of_attorney', 'validate.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json'))
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code!).and_return(true)
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_poa_code_for_current_user!).and_return(true)
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) do
            temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json'))
            temp = JSON.parse(temp)

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
                                                      'default_with_source.json')))

          let(:scopes) { %w[claim.read claim.write] }
          let(:data) { { data: { attributes: nil } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            with_okta_user(scopes) do
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
