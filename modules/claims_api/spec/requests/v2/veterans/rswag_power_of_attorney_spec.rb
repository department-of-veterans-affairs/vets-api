# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'
require 'bgs_service/local_bgs'

describe 'PowerOfAttorney',
         openapi_spec: Rswag::TextHelpers.new.claims_api_docs do
  let(:local_bgs) { ClaimsApi::LocalBGS }

  claimant_data = {
    'claimantId' => '1013093331V548481',
    'address' => {
      'addressLine1' => '123 anystreet',
      'city' => 'anytown',
      'stateCode' => 'OR',
      'countryCode' => 'US',
      'zipCode' => '12345'
    },
    'relationship' => 'Spouse'
  }

  path '/veterans/{veteranId}/power-of-attorney' do
    get 'Find current Power of Attorney for a Veteran.' do
      tags 'Power of Attorney'
      operationId 'findPowerOfAttorney'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Retrieves current Power of Attorney for Veteran or empty data if no POA is assigned.'

      let(:Authorization) { 'Bearer token' }

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:poa_code) { 'A1Q' }
      let(:bgs_poa) { { person_org_name: "#{poa_code} name-here" } }

      describe 'Getting a successful response' do
        response '200', 'Successful response with a current Power of Attorney' do
          schema JSON.parse(File.read(Rails.root.join('spec',
                                                      'support',
                                                      'schemas',
                                                      'claims_api',
                                                      'veterans',
                                                      'power-of-attorney',
                                                      'get.json')))

          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            FactoryBot.create(:veteran_representative, representative_id: '12345',
                                                       poa_codes: [poa_code],
                                                       first_name: 'Firstname',
                                                       last_name: 'Lastname',
                                                       phone: '555-555-5555')
            mock_ccg(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })

            FactoryBot.create(:veteran_representative, representative_id: '12345',
                                                       poa_codes: ['H1A'],
                                                       first_name: 'Firstname',
                                                       last_name: 'Lastname',
                                                       phone: '555-555-5555')
            mock_ccg(scopes) do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            FactoryBot.create(:veteran_representative, representative_id: '12345',
                                                       poa_codes: [poa_code],
                                                       first_name: 'Firstname',
                                                       last_name: 'Lastname',
                                                       phone: '555-555-5555')
            FactoryBot.create(:veteran_representative, representative_id: '54321',
                                                       poa_codes: [poa_code],
                                                       first_name: 'Another',
                                                       last_name: 'Name',
                                                       phone: '222-222-2222')
            mock_ccg(scopes) do
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

  path '/veterans/{veteranId}/2122a' do
    post 'Appoint an individual Power of Attorney for a Veteran.' do
      tags 'Power of Attorney'
      operationId 'post2122a'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a]
      post_description = <<~VERBIAGE
        Dependent Claimant Information:\n
          - If dependent claimant information is included in the request, the dependentʼs relationship to the Veteran
          will be validated.\n
          - In this case, the representative will be appointed to the dependent claimant, not the Veteran.\n\n

        Response Information:\n
          - A 202 response indicates that the submission was accepted.\n
          - To check the status of a POA submission, use GET /veterans/{veteranId}/power-of-attorney/{id} endpoint.\n
      VERBIAGE
      description post_description
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:poa_code) { '067' }
      let(:bgs_poa) { { person_org_name: "#{poa_code} name-here" } }

      request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                                    'power_of_attorney', '2122a', 'valid.json').read)

      request_template_with_dependent = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2',
                                                                   'veterans', 'power_of_attorney', '2122a',
                                                                   'valid.json').read)

      request_template_with_dependent['data']['attributes']['claimant'] = claimant_data

      parameter name: :power_of_attorney_request, in: :body,
                schema: SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a][:schema]

      parameter in: :body, examples: {
        'POA for Veteran' => {
          value: request_template
        },
        'POA for Dependent Claimant' => {
          value: request_template_with_dependent
        }
      }

      describe 'Getting a successful response' do
        response '202', 'Valid request response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122a', 'submit.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:power_of_attorney_request) do
            data
          end

          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            FactoryBot.create(:veteran_representative, representative_id: '999999999999',
                                                       poa_codes: [poa_code],
                                                       first_name: 'Firstname',
                                                       last_name: 'Lastname',
                                                       phone: '555-555-5555')
            mock_ccg(scopes) do
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

          it 'returns a valid 202 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'invalid_schema.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
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

  path '/veterans/{veteranId}/2122' do
    post 'Appoint an organization Power of Attorney for a Veteran.' do
      post_description = <<~VERBIAGE
        Dependent Claimant Information:\n
          - If dependent claimant information is included in the request, the dependentʼs relationship to the Veteran
          will be validated.\n
          - In this case, the representative will be appointed to the dependent claimant, not the Veteran.\n\n

        Response Information:\n
          - A 202 response indicates that the submission was accepted.\n
          - To check the status of a POA submission, use GET /veterans/{veteranId}/power-of-attorney/{id} endpoint.\n
      VERBIAGE
      description post_description
      tags 'Power of Attorney'
      operationId 'post2122'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney2122]

      let(:Authorization) { 'Bearer token' }
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.write] }
      let(:organization_poa_code) { '083' }
      let(:bgs_poa) { { person_org_name: "#{organization_poa_code} name-here" } }

      request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                                    'power_of_attorney', '2122', 'valid.json').read)

      request_template_with_dependent = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2',
                                                                   'veterans', 'power_of_attorney', '2122',
                                                                   'valid.json').read)

      request_template_with_dependent['data']['attributes']['claimant'] = claimant_data

      parameter name: :power_of_attorney_request, in: :body,
                schema: SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a][:schema]

      parameter in: :body, examples: {
        'POA for Veteran' => {
          value: request_template
        },
        'POA for Dependent Claimant' => {
          value: request_template_with_dependent
        }
      }

      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                               'power_of_attorney', '2122', 'valid.json').read
        JSON.parse(temp)
      end

      describe 'Getting a successful response' do
        response '202', 'Valid request response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                                      'power_of_attorney', '2122', 'submit.json')))

          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            FactoryBot.create(:veteran_organization, poa: organization_poa_code,
                                                     name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS",
                                                     phone: '555-555-5555')
            FactoryBot.create(:veteran_representative, representative_id: '999999999999',
                                                       poa_codes: [organization_poa_code], phone: '555-555-5555')

            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          let(:power_of_attorney_request) do
            data
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 202 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'invalid_schema.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
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

  path '/veterans/{veteranId}/2122a/validate' do
    post 'Validates a 2122a form submission.' do
      tags 'Power of Attorney'
      operationId 'post2122aValidate'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      let(:scopes) { %w[system/claim.read system/claim.write] }

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a]
      pdf_description = <<~VERBIAGE
        Validates a request appointing an individual as Power of Attorney (21-22a).
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          let(:poa_code) { '067' }

          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122a', 'validate.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            FactoryBot.create(:veteran_representative, representative_id: '999999999999',
                                                       poa_codes: [poa_code],
                                                       first_name: 'Firstname',
                                                       last_name: 'Lastname',
                                                       phone: '555-555-5555')

            mock_ccg(scopes) do
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
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'invalid_schema.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
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

  path '/veterans/{veteranId}/2122/validate' do
    post 'Validates a 2122 form submission.' do
      tags 'Power of Attorney'
      operationId 'post2122Validate'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney2122]

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }

      pdf_description = <<~VERBIAGE
        Validates a request appointing an organization as Power of Attorney (21-22).
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          let(:poa_code) { '083' }

          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122', 'validate.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          before do |example|
            FactoryBot.create(:veteran_organization, poa: poa_code)
            FactoryBot.create(:veteran_representative, representative_id: '999999999999', poa_codes: [poa_code])

            mock_ccg(scopes) do
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
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'invalid_schema.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
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

  path '/veterans/{veteranId}/power-of-attorney/{id}' do
    get 'Checks status of Power of Attorney appointment form submission' do
      description 'Gets the Power of Attorney appointment request status (21-22/21-22a)'
      tags 'Power of Attorney'
      operationId 'getPowerOfAttorneyStatus'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'
      parameter name: 'id',
                in: :path,
                required: true,
                type: :string,
                example: '12e13134-7229-4e44-90ae-bcea2a4525fa',
                description: 'The ID of the 21-22 submission'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:poa) { create(:power_of_attorney, :pending) }
      let(:id) { poa.id }

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2',
                                                      'veterans', 'power_of_attorney', 'status.json')))

          before do |example|
            mock_ccg(scopes) do
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
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:id) { -1 }
          before do |example|
            mock_ccg(scopes) do
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

  path '/veterans/{veteranId}/power-of-attorney-request', production: false do
    post 'Create a Power of Attorney appointment request' do
      description 'Creates a Power of Attorney appointment request.'
      tags 'Power of Attorney'
      operationId 'postPowerOfAttorneyRequest'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney_request]

      let(:Authorization) { 'Bearer token' }
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.write] }
      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                               'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
        JSON.parse(temp)
      end

      describe 'Getting a successful response' do
        response '201', 'Valid request response' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                                      'power_of_attorney', 'request_representative', 'submit.json')))

          before do |example|
            allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return false
            allow_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
              .to receive(:submit_request)
              .and_return({ 'procId' => '12345' })
            FactoryBot.create(:veteran_representative, representative_id: '999999999999', poa_codes: ['067'],
                                                       first_name: 'Abraham', last_name: 'Lincoln',
                                                       user_types: ['veteran_service_officer'])
            FactoryBot.create(:veteran_organization, poa: '067', name: 'DISABLED AMERICAN VETERANS')

            mock_ccg(scopes) do
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

          it 'returns a valid 201 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          let(:Authorization) { nil }

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

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', 'request_representative', 'invalid_schema.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
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
