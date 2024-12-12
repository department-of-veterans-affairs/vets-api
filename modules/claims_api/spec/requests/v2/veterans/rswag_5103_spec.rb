# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'

# doc generation for V2 5103 temporarily disabled
describe 'EvidenceWaiver5103',
         openapi_spec: Rswag::TextHelpers.new.claims_api_docs do
  path '/veterans/{veteranId}/claims/{id}/5103' do
    post 'Submit Evidence Waiver 5103' do
      tags '5103 Waiver'
      operationId 'submitEvidenceWaiver5103'
      security [
        { productionOauth: ['system/claim.write'] },
        { sandboxOauth: ['system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      description 'Submit Evidence Waiver 5103 for Veteran.'

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

      let(:id) { '256803' }
      let(:Authorization) { 'Bearer token' }
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName

      parameter name: :evidence_waiver_submission_request, in: :body,
                schema: SwaggerSharedComponents::V2.body_examples[:evidence_waiver_submission_request][:schema]
      let(:target_veteran) do
        OpenStruct.new(
          icn: '1012667145V762142',
          first_name: 'Tamara',
          last_name: 'Ellis',
          loa: { current: 3, highest: 3 },
          edipi: '1007697216',
          ssn: '796130115',
          participant_id: '600043201',
          mpi: OpenStruct.new(
            icn: '1012667145V762142',
            profile: OpenStruct.new(ssn: '796130115')
          )
        )
      end

      describe 'Getting a successful response' do
        response '202', 'Successful response' do
          schema JSON.parse(Rails.root.join('spec',
                                            'support',
                                            'schemas',
                                            'claims_api',
                                            'v2',
                                            'veterans',
                                            'submit_waiver_5103.json').read)

          let(:scopes) { %w[system/claim.write] }
          let(:evidence_waiver_submission_request) {}
          before do |example|
            allow_any_instance_of(ClaimsApi::V2::ApplicationController)
              .to receive(:target_veteran).and_return(target_veteran)

            bgs_claim_response = build(:bgs_response_with_one_lc_status).to_h
            bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = '600043201'
            bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_clmant_id] = target_veteran[:participant_id]

            expect_any_instance_of(ClaimsApi::EbenefitsBnftClaimStatusWebService)
              .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)

            mock_ccg(scopes) do
              allow_any_instance_of(ClaimsApi::PersonWebService)
                .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })
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
                                            'default.json').read)

          let(:Authorization) { nil }
          let(:scopes) { %w[system/claim.read] }
          let(:evidence_waiver_submission_request) {}

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
        response '404', 'NotFound' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:Authorization) { nil }
          let(:scopes) { %w[system/claim.read] }
          let(:sponsorIcn) { '1012861229V078999' } # rubocop:disable RSpec/VariableName
          let(:evidence_waiver_submission_request) {}

          before do |example|
            mock_ccg(scopes) do
              allow_any_instance_of(ClaimsApi::EbenefitsBnftClaimStatusWebService)
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
