# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'
require 'bgs_service/local_bgs'

# doc generation for V2 ITFs temporarily disabled by API-13879
describe 'PowerOfAttorney',
         swagger_doc: Rswag::TextHelpers.new.claims_api_docs, document: false do
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
      description 'Retrieves current Power of Attorney for Veteran.'

      let(:Authorization) { 'Bearer token' }
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
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

      describe 'No POA assigned to Veteran' do
        let(:bgs_poa) { { person_org_name: nil } }

        response '204', 'Successful response with no current Power of Attorney' do
          before do |example|
            expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            mock_ccg(scopes) do |auth_header|
              Authorization = auth_header # rubocop:disable Naming/ConstantName
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: response.body
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
                                                      'default.json')))

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

      describe 'Getting a 403 response' do
        let(:veteranId) { 'not-the-same-id-as-tamara' } # rubocop:disable RSpec/VariableName

        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

          before do |example|
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

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

          it 'returns a 403 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/power-of-attorney:appoint-individual' do
    put 'Appoint an individual Power of Attorney for a Veteran.' do
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

      describe 'Getting a successful response' do
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

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

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

      describe 'Getting a 403 response' do
        let(:veteranId) { 'not-the-same-id-as-tamara' } # rubocop:disable RSpec/VariableName

        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

          before do |example|
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

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

          it 'returns a 403 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

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

  path '/veterans/{veteranId}/power-of-attorney:appoint-organization' do
    put 'Appoint an organization Power of Attorney for a Veteran.' do
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
      b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
      let(:data) do
        {
          serviceOrganization: {
            poaCode: organization_poa_code.to_s
          },
          signatures: {
            veteran: b64_image,
            representative: b64_image
          }
        }
      end

      describe 'Getting a successful response' do
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

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

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

      describe 'Getting a 403 response' do
        let(:veteranId) { 'not-the-same-id-as-tamara' } # rubocop:disable RSpec/VariableName

        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

          before do |example|
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

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

          it 'returns a 403 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

          before do |example|
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })
              Authorization = auth_header # rubocop:disable Naming/ConstantName
              data[:serviceOrganization][:poaCode] = individual_poa_code.to_s
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
end
