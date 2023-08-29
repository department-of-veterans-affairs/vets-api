# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../rails_helper'
require_relative '../../support/swagger_shared_components/v1'

describe 'Intent to file', swagger_doc: 'modules/claims_api/app/swagger/claims_api/v1/swagger.json' do # rubocop:disable RSpec/DescribeClass
  path '/forms/0966' do
    get 'Get 0966 JSON Schema for form.' do
      deprecated true
      tags 'Intent to File'
      operationId 'get0966JsonSchema'
      produces 'application/json'
      description 'Returns a single 0966 JSON schema to auto generate a form.'
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

    post 'Submit form 0966 Intent to File.' do
      tags 'Intent to File'
      operationId 'post0966itf'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      post_description = <<~VERBIAGE
        Establishes an intent to file for disability compensation, burial, or pension claims.
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

      parameter SwaggerSharedComponents::V1.body_examples[:intent_to_file]

      describe 'Getting a successful response' do
        response '200', '0966 Response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'intent_to_file', 'submission.json')))

          let(:scopes) { %w[claim.write] }
          let(:data) { { data: { attributes: { type: 'compensation' } } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
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
          let(:data) { { data: { attributes: { type: 'compensation' } } } }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
                allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
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

      describe 'Getting a 403 response' do
        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:data) { { data: { attributes: { type: 'burial' } } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              expect_any_instance_of(
                ClaimsApi::V1::Forms::IntentToFileController
              ).to receive(:veteran_submitting_burial_itf?).and_return(true)
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
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

          it 'returns a 403 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default_with_source.json')))

          let(:scopes) { %w[claim.write] }
          let(:data) { { data: { attributes: { type: 'HelloWorld' } } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/0966/active' do
    get 'Returns last active 0966 Intent to File form submission.' do
      tags 'Intent to File'
      operationId 'active0966itf'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Returns the last active 0966 form for a Veteran.'

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }

      parameter name: 'type',
                in: :query,
                type: :string,
                description: 'The type of 0966 you wish to get the active submission for.',
                example: 'compensation'

      let(:Authorization) { 'Bearer token' }

      describe 'Getting a 200 response' do
        response '200', '0966 response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'intent_to_file', 'active.json')))

          let(:scopes) { %w[claim.write] }
          let(:type) { 'compensation' }

          before do |example|
            stub_poa_verification
            stub_mpi
            Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
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
            Timecop.return
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
          let(:type) { 'compensation' }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
                allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:type) { 'compensation' }

          before do |example|
            allow_any_instance_of(BGS::IntentToFileWebService)
              .to receive(:find_intent_to_file_by_ptcpnt_id_itf_type_cd).and_return([])
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
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

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:scopes) { %w[claim.write] }
          let(:type) { 'HelloWorld' }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/forms/0966/validate' do
    post 'Test the 0966 Intent to File form submission.' do
      deprecated true
      tags 'Intent to File'
      operationId 'validate0966itf'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      validate_description = <<~VERBIAGE
        Test to ensure the form submission works with your parameters.
        Submission is validated against the GET /forms/0966 schema.
      VERBIAGE
      description validate_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }
      let(:Authorization) { 'Bearer token' }

      parameter SwaggerSharedComponents::V1.body_examples[:intent_to_file]

      describe 'Getting a successful response' do
        response '200', '0966 Response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                                      'intent_to_file', 'validate.json')))

          let(:scopes) { %w[claim.write] }
          let(:data) { { data: { attributes: { type: 'compensation' } } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
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
          let(:data) { { data: { attributes: { type: 'compensation' } } } }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
                allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
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
        response '422', 'Unprocessable' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default_with_source.json')))

          let(:scopes) { %w[claim.write] }
          let(:data) { { data: { attributes: nil } } }

          before do |example|
            stub_poa_verification
            stub_mpi

            mock_acg(scopes) do
              VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
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

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end
