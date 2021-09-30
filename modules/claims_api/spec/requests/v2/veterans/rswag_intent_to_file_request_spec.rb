# frozen_string_literal: true

require 'swagger_helper'
require 'rails_helper'

describe 'IntentToFile', swagger_doc: 'modules/claims_api/app/swagger/claims_api/v2/swagger.json' do
  path '/veterans/{veteranId}/intent-to-files/{type}' do
    get "Returns last active Intent to File form submission for given 'type'." do
      tags 'Intent to File'
      operationId 'active0966itf'
      security [
        { productionOauth: ['claim.read'] },
        { sandboxOauth: ['claim.read'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description "Returns Veteran's last active Intent to File submission for given 'type'."

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                description: 'ID of Veteran'
      parameter name: 'type',
                in: :path,
                required: true,
                type: :string,
                description: 'Type of Intent to File to return. Available values - compensation, pension, burial'
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:type) { 'compensation' }
      let(:Authorization) { 'Bearer token' }

      describe 'Getting a successful response' do
        response '200', 'Successful response with active Intent to File' do
          schema JSON.parse(
            File.read(
              Rails.root.join(
                'spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans', 'intent_to_files', 'intent_to_file.json'
              )
            )
          )

          let(:bgs_response) do
            JSON.parse(
              File.read(
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'intent_to_files',
                                'find_by_ptcpnt_id_and_itf_type.json')
              ),
              symbolize_names: true
            )
          end
          let(:scopes) { %w[claim.read] }

          before do |example|
            Timecop.freeze(Time.zone.parse('2022-01-01T08:00:00Z'))

            with_okta_user(scopes) do
              expect_any_instance_of(BGS::IntentToFileWebService)
                .to receive(:find_intent_to_file_by_ptcpnt_id_itf_type_cd).and_return(bgs_response)

              submit_request(example.metadata)
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
          let(:scopes) { %w[claim.read] }

          before do |example|
            with_okta_user(scopes) do
              expect_any_instance_of(BGS::IntentToFileWebService)
                .to receive(:find_intent_to_file_by_ptcpnt_id_itf_type_cd).and_return(nil)

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
