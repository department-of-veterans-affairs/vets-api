# frozen_string_literal: true

require 'swagger_helper'
require 'rails_helper'

describe 'Claims', swagger_doc: 'modules/claims_api/app/swagger/claims_api/v2/swagger.json' do
  path '/veterans/{veteranId}/claims' do
    get 'Find all benefits claims for a Veteran.' do
      tags 'Claims'
      operationId 'findClaims'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Retrieves all claims for Veteran.'

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                description: 'ID of Veteran'
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }

      describe 'Getting a successful response' do
        response '200', 'claim response' do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans', 'claims', 'claims.json')
            )
          )

          let(:bgs_response) do
            bgs_data = JSON.parse(
              File.read(
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'claims',
                                'claims_by_participant_id_response.json')
              ),
              symbolize_names: true
            )
            bgs_data[:benefit_claims_dto][:benefit_claim][0][:claim_dt] = Date.parse(
              bgs_data[:benefit_claims_dto][:benefit_claim][0][:claim_dt]
            )
            bgs_data
          end
          let(:scopes) { %w[claim.read] }

          before do |example|
            with_okta_user(scopes) do
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_response)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

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

          let(:Authorization) { nil }
          let(:scopes) { %w[claim.read] }

          before do |example|
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

      describe 'Getting a 403 response' do
        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }
          let(:scopes) { %w[claim.read] }

          before do |example|
            with_okta_user(scopes) do
              expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

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

  path '/veterans/{veteranId}/claims/{id}' do
    get 'Find claim by ID' do
      tags 'Claims'
      operationId 'findClaimById'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, description: 'The ID of the claim being requested'
      description 'Retrieves a specific claim for a Veteran'

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                description: 'ID of Veteran'
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:id) { '600131328' }

      describe 'Getting a successul response' do
        response '200', 'claim response' do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans', 'claims', 'claim.json')
            )
          )

          let(:bgs_response) do
            bgs_data = JSON.parse(
              File.read(
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'claims',
                                'claim_by_id_response.json')
              ),
              symbolize_names: true
            )
            bgs_data[:benefit_claim_details_dto][:claim_dt] = Date.parse(
              bgs_data[:benefit_claim_details_dto][:claim_dt]
            )
            bgs_data
          end
          let(:scopes) { %w[claim.read] }

          before do |example|
            with_okta_user(scopes) do
              expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(nil)
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_response)

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

          let(:Authorization) { nil }
          let(:scopes) { %w[claim.read] }

          before do |example|
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

      describe 'Getting a 403 response' do
        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }
          let(:scopes) { %w[claim.read] }

          before do |example|
            with_okta_user(scopes) do
              expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

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

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors', 'default.json')
            )
          )
          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }
          let(:scopes) { %w[claim.read] }

          before do |example|
            with_okta_user(scopes) do
              expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(nil)
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

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
