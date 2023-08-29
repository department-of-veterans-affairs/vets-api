# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'

# doc generation for V2 5103 temporarily disabled
describe 'EvidenceWaiver5103',
         swagger_doc: Rswag::TextHelpers.new.claims_api_docs do
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
                example: '1234',
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

      describe 'Getting a successful response' do
        response '200', 'Successful response' do
          schema JSON.parse(File.read(Rails.root.join('spec',
                                                      'support',
                                                      'schemas',
                                                      'claims_api',
                                                      'v2',
                                                      'veterans',
                                                      'submit_waiver_5103.json')))

          let(:scopes) { %w[system/claim.write] }

          before do |example|
            mock_ccg(scopes) do
              VCR.use_cassette('bgs/benefit_claim/update_5103_200') do
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

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

      describe 'Getting a 403 response' do
        response '403', 'Forbidden' do
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                                      'default.json')))

          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }
          let(:scopes) { %w[system/claim.read] }

          before do |example|
            mock_acg(scopes) do
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

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
end
