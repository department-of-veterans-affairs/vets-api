# frozen_string_literal: true

require 'swagger_helper'
require 'rails_helper'
require_relative '../../support/swagger_shared_components'

describe 'Veteran Identifier', swagger_doc: 'v2/swagger.json' do # rubocop:disable RSpec/DescribeClass
  path '/veteran-id:find' do
    post 'Retrieve id of Veteran.' do
      tags 'Veteran Identifier'
      operationId 'postVeteranId'
      security [bearer_token: []]
      consumes 'application/json'
      produces 'application/json'
      description "Allows authenticated Veterans and Veteran representatives to retrieve a Veteran's id."

      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents.body_examples[:veteran_identifier]

      let(:data) do
        {
          ssn: '796130115',
          birthdate: '1967-06-19',
          firstName: 'Tamara',
          lastName: 'Ellis'
        }
      end

      describe 'Getting a successful response' do
        response '200', "Veteran's unique identifier" do
          schema JSON.parse(
            File.read(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'veteran_identifier', 'submission.json')
            )
          )

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

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 400 response' do
        context 'when parameters are missing' do
          before do |example|
            data[:ssn] = nil
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          response '400', 'Bad Request' do
            schema JSON.parse(
              File.read(
                Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors', 'default.json')
              )
            )

            it 'returns a 400 response' do |example|
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
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors', 'default.json')
            )
          )

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        before do |example|
          data[:ssn] = '555555555'  # SSN other than Tamara's
          submit_request(example.metadata)
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
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors', 'default.json')
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
