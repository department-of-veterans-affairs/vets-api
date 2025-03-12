# frozen_string_literal: true

require 'swagger_helper'
require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/local_bgs'
require 'bgs_service/tracked_item_service'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'

describe 'Claims',
         openapi_spec: Rswag::TextHelpers.new.claims_api_docs do
  let(:local_claims_status_service) do
    ClaimsApi::EbenefitsBnftClaimStatusWebService
  end

  path '/veterans/{veteranId}/claims' do
    get 'Find all benefits claims for a Veteran.' do
      tags 'Claims'
      operationId 'findClaims'
      security [
        { productionOauth: ['system/claim.read'] },
        { sandboxOauth: ['system/claim.read'] },
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

      describe 'Getting a successful response' do
        response '200', 'claim response' do
          schema JSON.parse(
            Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans', 'claims',
                            'claims.json').read
          )

          let(:bgs_response) do
            bgs_data = JSON.parse(
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'claims',
                              'claims_by_participant_id_response.json').read,
              symbolize_names: true
            )
            bgs_data[:benefit_claims_dto][:benefit_claim][0][:claim_dt] = Date.parse(
              bgs_data[:benefit_claims_dto][:benefit_claim][0][:claim_dt]
            )
            bgs_data
          end
          let(:scopes) { %w[system/claim.read] }

          before do |example|
            mock_ccg(scopes) do
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                expect_any_instance_of(local_claims_status_service)
                  .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_response)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:where).and_return([])

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
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:Authorization) { nil }
          let(:scopes) { %w[system/claim.read] }

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
    end
  end

  path '/veterans/{veteranId}/claims/{id}' do
    get 'Find claim by ID.' do
      tags 'Claims'
      operationId 'findClaimById'
      security [
        { productionOauth: ['system/claim.read'] },
        { sandboxOauth: ['system/claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Retrieves a specific claim for a Veteran'
      parameter name: :id,
                in: :path,
                type: :string,
                example: '600400703',
                description: 'The ID of the claim being requested'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:id) { '600131328' }
      let(:target_veteran) do
        OpenStruct.new(
          icn: '1013062086V794840',
          first_name: 'abraham',
          last_name: 'lincoln',
          loa: { current: 3, highest: 3 },
          ssn: '796111863',
          edipi: '8040545646',
          participant_id: '600061742',
          mpi: OpenStruct.new(
            icn: '1013062086V794840',
            profile: OpenStruct.new(ssn: '796111863')
          )
        )
      end

      describe 'Established Claim' do
        response '200', 'claim response' do
          schema JSON.parse(
            Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans', 'claims',
                            'claim.json').read
          )

          let(:bgs_response) do
            bgs_data = JSON.parse(
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'claims',
                              'claim_by_id_response.json').read,
              symbolize_names: true
            )
            bgs_data[:benefit_claim_details_dto][:claim_dt] = Date.parse(
              bgs_data[:benefit_claim_details_dto][:claim_dt]
            )
            bgs_data
          end
          let(:scopes) { %w[system/claim.read] }

          before do |example|
            mock_ccg(scopes) do
              VCR.use_cassette('claims_api/bgs/tracked_item_service/claims_v2_show_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  bgs_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = target_veteran.participant_id
                  expect_any_instance_of(local_claims_status_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_response)
                  allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                    .to receive(:target_veteran).and_return(target_veteran)
                  submit_request(example.metadata)
                end
              end
            end
          end

          after do |example|
            response_title = example.metadata[:description]
            example.metadata[:response][:content] = {
              'application/json' => {
                examples: {
                  "#{response_title}": {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
          end

          it 'returns a 200 response for established claim' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Errored Claim' do
        response '200', 'errored claim response' do
          schema JSON.parse(
            Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'claims',
                            'claim_by_id_response.json').read
          )

          let(:bgs_response) do
            bgs_data = JSON.parse(
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'claims',
                              'claim_by_id_response.json').read,
              symbolize_names: true
            )
            bgs_data[:benefit_claim_details_dto][:claim_dt] = Date.parse(
              bgs_data[:benefit_claim_details_dto][:claim_dt]
            )
            bgs_data
          end
          let(:scopes) { %w[system/claim.read] }

          let(:id) do
            'd5536c5c-0465-4038-a368-1a9d9daf65c9'
          end

          let(:evss_response) do
            [{ 'key' => 'form526.serviceInformation.reservesNationalGuardService.unitPhone.phoneNumber.Pattern',
               'severity' => 'ERROR',
               'detail' => 'must match d{7}',
               'text' => 'must match d{7}' },
             { 'key' => 'form526.veteran.homelessness.pointOfContact.primaryPhone.phoneNumber.Pattern',
               'severity' => 'ERROR',
               'detail' => 'must match d{7}',
               'text' => 'must match d{7}' }]
          end

          before do |example|
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claim') do
                bgs_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = target_veteran.participant_id
                allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:target_veteran).and_return(target_veteran)
                allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:authenticate).and_return(true)
                allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                  .to receive(:find_bgs_claim!).and_return(nil)
                create(:auto_established_claim,
                       source: 'abraham lincoln',
                       auth_headers: auth_header,
                       evss_id: 600_118_851,
                       veteran_icn: '1013062086V794840',
                       id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                       status: 'errored',
                       evss_response:)

                submit_request(example.metadata)
              end
            end
          end

          after do |example|
            response_title = example.metadata[:description]
            example.metadata[:response][:content] = {
              'application/json' => {
                examples: {
                  "#{response_title}": {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
          end

          it 'returns a 200 response for errored claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:Authorization) { nil }
          let(:scopes) { %w[system/claim.read] }

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
          schema JSON.parse(
            Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors', 'default.json').read
          )
          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }
          let(:scopes) { %w[system/claim.read] }

          before do |example|
            mock_ccg(scopes) do
              expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_and_icn).and_return(nil)
              expect_any_instance_of(local_claims_status_service).to receive(
                :find_benefit_claim_details_by_benefit_claim_id
              ).and_return(nil)

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
