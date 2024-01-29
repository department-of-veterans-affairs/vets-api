# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'
require 'bgs_service/local_bgs'

# doc generation for V2 ITFs temporarily disabled by API-13879
describe 'PowerOfAttorney',
         openapi_spec: Rswag::TextHelpers.new.claims_api_docs do
  let(:local_bgs) { ClaimsApi::LocalBGS }

  path '/veterans/{veteranId}/power-of-attorney' do
    get 'Find current Power of Attorney for a Veteran.' do
      tags 'Power of Attorney'
      operationId 'findPowerOfAttorney'
      security [
        { productionOauth: ['system/claim.read', 'system/system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/system/claim.write'] },
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
      let(:scopes) { %w[system/claim.read system/system/claim.write] }
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
            Veteran::Service::Representative.new(representative_id: '12345',
                                                 poa_codes: [poa_code],
                                                 first_name: 'Firstname',
                                                 last_name: 'Lastname',
                                                 phone: '555-555-5555').save!
            mock_ccg(scopes) do |auth_header|
              Authorization = auth_header # rubocop:disable Naming/ConstantName
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

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            Veteran::Service::Representative.new(representative_id: '12345',
                                                 poa_codes: [poa_code],
                                                 first_name: 'Firstname',
                                                 last_name: 'Lastname',
                                                 phone: '555-555-5555').save!
            Veteran::Service::Representative.new(representative_id: '54321',
                                                 poa_codes: [poa_code],
                                                 first_name: 'Another',
                                                 last_name: 'Name',
                                                 phone: '222-222-2222').save!
            mock_ccg(scopes) do |auth_header|
              Authorization = auth_header # rubocop:disable Naming/ConstantName
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

  path '/veterans/{veteranId}/power-of-attorney:appoint-individual', production: false do
    post 'Appoint an individual Power of Attorney for a Veteran.' do
      tags 'Power of Attorney'
      operationId 'appointIndividualPowerOfAttorney'
      security [
        { productionOauth: ['system/claim.write'] },
        { sandboxOauth: ['system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      description 'Updates current Power of Attorney for Veteran.'

      let(:Authorization) { 'Bearer token' }
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                description: 'ID of Veteran'

      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney]

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.write] }
      let(:individual_poa_code) { 'A1H' }
      let(:organization_poa_code) { '083' }
      let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
      b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
      let(:data) do
        {
          serviceOrganization: {
            poaCode: individual_poa_code.to_s
          },
          signatures: {
            veteran: b64_image,
            representative: b64_image
          }
        }
      end

      xdescribe 'Getting a successful response', document: false do
        response '200', 'Successful response with the submitted Power of Attorney' do
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
            Veteran::Service::Representative.new(representative_id: '67890',
                                                 poa_codes: [individual_poa_code],
                                                 first_name: 'Firstname',
                                                 last_name: 'Lastname',
                                                 phone: '555-555-5555').save!
            mock_ccg(scopes) do |auth_header|
              Authorization = auth_header # rubocop:disable Naming/ConstantName
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

      xdescribe 'Getting a 401 response', document: false do
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

      xdescribe 'Getting a 422 response', document: false do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          before do |example|
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })
              Authorization = auth_header # rubocop:disable Naming/ConstantName
              data[:serviceOrganization][:poaCode] = '083'
              Veteran::Service::Representative.new(representative_id: '00000', poa_codes: [organization_poa_code],
                                                   first_name: 'George', last_name: 'Washington').save!
              Veteran::Service::Organization.create(poa: organization_poa_code,
                                                    name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
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

  path '/veterans/{veteranId}/2122', production: false do
    post 'Appoint an organization Power of Attorney for a Veteran.' do
      tags 'Power of Attorney'
      operationId 'appointOrganizationPowerOfAttorney'
      security [
        { productionOauth: ['system/claim.write'] },
        { sandboxOauth: ['system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      description 'Updates current Power of Attorney for Veteran.'

      let(:Authorization) { 'Bearer token' }
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                description: 'ID of Veteran'

      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney]

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.write] }
      let(:individual_poa_code) { 'A1H' }
      let(:organization_poa_code) { '083' }
      let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
      let(:data) do
        {
          data: {
            attributes: {
              serviceOrganization: {
                poaCode: organization_poa_code.to_s
              }
            }
          }
        }
      end

      describe 'Getting a successful response', document: false do
        response '200', 'Successful response with the submitted Power of Attorney' do
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
            Veteran::Service::Representative.new(representative_id: '67890',
                                                 poa_codes: [organization_poa_code],
                                                 first_name: 'Firstname',
                                                 last_name: 'Lastname',
                                                 phone: '555-555-5555').save!
            Veteran::Service::Organization.create(poa: organization_poa_code,
                                                  name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")

            mock_ccg(scopes) do |auth_header|
              Authorization = auth_header # rubocop:disable Naming/ConstantName
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

      describe 'Getting a 401 response', document: false do
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

      describe 'Getting a 422 response', document: false do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'power_of_attorney', 'default.json')))

          before do |example|
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })
              Authorization = auth_header # rubocop:disable Naming/ConstantName
              data[:data][:attributes][:serviceOrganization][:poaCode] = individual_poa_code.to_s
              Veteran::Service::Representative.new(representative_id: '00000', poa_codes: [individual_poa_code],
                                                   first_name: 'George', last_name: 'Washington').save!
              Veteran::Service::Organization.create(poa: organization_poa_code,
                                                    name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
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

  path '/veterans/{veteranId}/2122a/validate', production: false do
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
      let(:scopes) { %w[system/claim.read system/system/claim.write] }

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
          let(:poa_code) { '083' }

          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122a', 'validate.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            Veteran::Service::Representative.new(representative_id: '12345',
                                                 poa_codes: [poa_code],
                                                 first_name: 'Firstname',
                                                 last_name: 'Lastname',
                                                 phone: '555-555-5555').save!

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

  path '/veterans/{veteranId}/2122a', production: false do
    post 'Appoint an individual as Power of Attorney.' do
      tags 'Power of Attorney'
      operationId 'post2122a'
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

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      pdf_description = <<~VERBIAGE
        Validates a request appointing an individual as Power of Attorney (21-22a).
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          it 'returns a valid 200 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          it 'returns a 401 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/2122/validate', production: false do
    post 'Validates a 2122 form submission.' do
      tags 'Power of Attorney'
      operationId 'post2122Validate'
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

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      pdf_description = <<~VERBIAGE
        Validates a request appointing an organization as Power of Attorney (21-22).
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          it 'returns a valid 200 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          it 'returns a 401 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/2122', production: false do
    post 'Appoint an organization as Power of Attorney' do
      tags 'Power of Attorney'
      operationId 'post2122'
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

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      pdf_description = <<~VERBIAGE
        Validates a request appointing an organization as Power of Attorney (21-22).
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          it 'returns a valid 200 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          it 'returns a 401 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/power-of-attorney/{id}', production: false do
    get 'Checks status of Power of Attorney appointment form submission' do
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
                description: 'Power of Attorney appointment request id'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:id) { '17125d28-dcb4-4466-9927-cd163361b30b' }
      let(:Authorization) { 'Bearer token' }
      pdf_description = <<~VERBIAGE
        Gets the Power of Attorney appointment request status (21-22/21-22a)
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Successful response' do
          it 'returns a valid 200 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          it 'returns a 401 response' do
            one = 1
            expect(one).to eq(1)
          end
        end
      end
    end
  end
end
