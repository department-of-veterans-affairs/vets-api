# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../rails_helper'
require_relative '../../support/swagger_shared_components/v1'

Rspec.describe 'EVSS Claims management', openapi_spec: 'modules/claims_api/app/swagger/claims_api/v1/swagger.json' do
  path '/claims' do
    get 'Find all benefits claims for a Veteran' do
      tags 'Claims'
      operationId 'findClaims'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      index_description = 'Uses the Veteran’s metadata in headers to retrieve all claims for that Veteran. '
      index_description += 'An authenticated Veteran making a request with this endpoint will return their own claims'
      index_description += ', if any.'
      description index_description

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'Wesley' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'Ford' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }

      let(:Authorization) { 'Bearer token' }

      let(:target_veteran) do
        OpenStruct.new(
          icn: '1012832025V743496',
          first_name: 'Wesley',
          last_name: 'Ford',
          loa: { current: 3, highest: 3 },
          edipi: '1007697216',
          ssn: '796043735',
          participant_id: '600061742',
          mpi: OpenStruct.new(
            icn: '1012832025V743496',
            profile: OpenStruct.new(ssn: '796043735')
          )
        )
      end

      describe 'Getting a 200 response' do
        response '200', 'claim response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'claims.json').read)

          let(:scopes) { %w[claim.read] }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claims_trimmed_down') do
                allow_any_instance_of(ClaimsApi::V1::ApplicationController)
                  .to receive(:target_veteran).and_return(target_veteran)
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
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read] }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
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
        response '404', 'Resource Not Found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read] }

          before do |example|
            stub_poa_verification

            allow_any_instance_of(ClaimsApi::EbenefitsBnftClaimStatusWebService).to receive(:all).and_raise(
              Common::Exceptions::ResourceNotFound.new(detail: 'The Resource was not found.')
            )
            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
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
    end
  end

  path '/claims/{id}' do
    get 'Find Claim by ID' do
      tags 'Claims'
      operationId 'findClaimById'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, description: 'The ID of the claim being requested'

      parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '796-04-3735' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'WESLEY' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'FORD' }

      parameter SwaggerSharedComponents::V1.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1986-05-06T00:00:00+00:00' }

      let(:Authorization) { 'Bearer token' }

      claim_by_id_description = 'Returns data such as processing status for a single claim by ID.'
      description claim_by_id_description

      before do
        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return false
      end

      describe 'Getting a 200 response' do
        response '200', 'claims response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'claim.json').read)

          let(:scopes) { %w[claim.read] }
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents, :established, source: 'abraham lincoln')
          end
          let(:id) { claim.id }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claim') do
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
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read] }
          let(:id) { '600118851' }
          let(:Authorization) { nil }

          before do |example|
            stub_poa_verification

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claim') do
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
        response '404', 'Record Not Found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read] }
          let(:id) { '999999999999999' }

          before do |example|
            stub_poa_verification

            allow(ClaimsApi::AutoEstablishedClaim).to receive(:find_by).and_return(nil)

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

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.read] }
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents)
          end
          let(:id) { claim.id }

          before do |example|
            stub_poa_verification

            claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
            claim.evss_response = [] # induce a 422 response
            allow(ClaimsApi::AutoEstablishedClaim).to receive(:find_by).and_return(claim)

            mock_acg(scopes) do
              VCR.use_cassette('claims_api/bgs/claims/claim') do
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
