# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../rails_helper'
require_relative '../../support/swagger_shared_components/v2'

describe 'Veteran Identifier', swagger_doc: Rswag::TextHelpers.new.claims_api_docs do # rubocop:disable RSpec/DescribeClass
  path '/veteran-id:find' do
    post 'Retrieve Veteran ID.' do
      tags 'Veteran Identifier'
      operationId 'postVeteranId'
      security [
        { productionOauth: ['system/claim.read'] },
        { sandboxOauth: ['system/claim.read'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      description "Allows authenticated and authorized users to retrieve a Veteran's ID."

      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents::V2.body_examples[:veteran_identifier]

      let(:data) do
        {
          ssn: '796130115',
          birthdate: '1967-06-19',
          firstName: 'Tamara',
          lastName: 'Ellis'
        }
      end
      let(:scopes) { %w[system/claim.read] }
      let(:test_user_icn) { '1012667145V762142' }
      let(:veteran) { ClaimsApi::Veteran.new }
      let(:veteran_mpi_data) { MPIData.new }

      describe 'Getting a successful response' do
        response '201', "Veteran's unique identifier" do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'veteran_identifier', 'submission.json')
            )
          )

          before do |example|
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

          it 'returns a valid 201 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        context 'when parameters are missing' do
          before do |example|
            mock_acg(scopes) do |auth_header|
              Authorization = auth_header # rubocop:disable Naming/ConstantName
              data[:ssn] = nil
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

          response '422', 'Bad Request' do
            schema JSON.parse(
              File.read(
                Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors', 'default.json')
              )
            )

            it 'returns a 422 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end
      end

      describe 'Getting a 401 response' do
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

        response '401', 'Unauthorized' do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors', 'default.json')
            )
          )

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 403 response' do
        before do |example|
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
          allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)
          expect(::Veteran::Service::Representative).to receive(:all_for_user).and_return([])
          mock_acg(scopes) do |auth_header|
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

        response '403', 'Forbidden' do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors', 'default.json')
            )
          )

          it 'returns a 403 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        before do |example|
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
          allow(veteran_mpi_data).to receive(:icn).and_return(nil)
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

        response '404', 'Resource not found' do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors', 'default.json')
            )
          )

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end
