# frozen_string_literal: true

require 'swagger_helper'
require 'rails_helper'

describe 'PowerOfAttorney', swagger_doc: 'modules/claims_api/app/swagger/claims_api/v2/swagger.json' do
  path '/veterans/{veteranId}/power-of-attorney' do
    get 'Find current Power of Attorney for a Veteran.' do
      tags 'Power of Attorney'
      operationId 'findPowerOfAttorney'
      security [
        { productionOauth: ['claim.read', 'claim.write'] },
        { sandboxOauth: ['claim.read', 'claim.write'] },
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
      let(:scopes) { %w[claim.read claim.write] }
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
            expect_any_instance_of(BGS::ClaimantWebService).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(BGS::OrgWebService).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            Veteran::Service::Representative.new(poa_codes: [poa_code],
                                                 first_name: 'Firstname',
                                                 last_name: 'Lastname',
                                                 phone: '555-555-5555').save!
            with_okta_user(scopes) do |auth_header|
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
            expect_any_instance_of(BGS::ClaimantWebService).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(BGS::OrgWebService).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            with_okta_user(scopes) do |auth_header|
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
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
          schema JSON.parse(File.read(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                                      'default.json')))

          before do |example|
            with_okta_user(scopes) do |auth_header|
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
end
